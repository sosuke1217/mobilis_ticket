require "digest"
require "json"
require "net/http"
require "singleton"
require "uri"

class ErrorHandlingService
  include Singleton

  NOTIFICATION_COOLDOWN = 15.minutes
  SAFE_CONTEXT_KEYS = %i[source request_id action reservation_id user_id job].freeze

  def self.log_error(error, context = {})
    instance.log_error(error, context)
  end

  def self.notify_admin(message, level = :warning)
    instance.log_error(
      StandardError.new(message.to_s),
      source: "manual_notification",
      action: level
    )
  end

  def log_error(error, context = {})
    safe_context = sanitize_context(context)
    Rails.logger.error(
      "[ERROR] class=#{error.class.name} source=#{safe_context[:source] || 'unknown'} " \
      "request_id=#{safe_context[:request_id] || 'none'}"
    )

    notify_admin_channels(error, safe_context) if Rails.env.production? || Rails.env.test?
  rescue => notification_error
    Rails.logger.error("[ERROR ALERT FAILURE] class=#{notification_error.class.name}")
  end

  private

  def sanitize_context(context)
    context.to_h.symbolize_keys
           .slice(*SAFE_CONTEXT_KEYS)
           .transform_values { |value| value.to_s.truncate(200) }
  end

  def notify_admin_channels(error, safe_context)
    key = notification_key(error, safe_context)
    return if Rails.cache.exist?(key)

    Rails.cache.write(key, true, expires_in: NOTIFICATION_COOLDOWN)
    notify_by_slack(error, safe_context) if ENV["SLACK_WEBHOOK_URL"].present?
    ErrorAlertMailer.failure(
      error_class: error.class.name,
      source: safe_context[:source] || "unknown",
      occurred_at: Time.current,
      context: safe_context.except(:source)
    ).deliver_now
  end

  def notify_by_slack(error, safe_context)
    uri = URI(ENV.fetch("SLACK_WEBHOOK_URL"))
    Net::HTTP.post(
      uri,
      {
        text: "Mobilis error: #{error.class.name} at #{safe_context[:source] || 'unknown'}"
      }.to_json,
      "Content-Type" => "application/json"
    )
  rescue => slack_error
    Rails.logger.error("[SLACK ALERT FAILURE] class=#{slack_error.class.name}")
  end

  def notification_key(error, safe_context)
    fingerprint = Digest::SHA256.hexdigest(
      [error.class.name, safe_context[:source]].join(":")
    )
    "error-alert/#{fingerprint}"
  end
end

require "digest"
require "json"
require "net/http"
require "singleton"
require "uri"

class ErrorHandlingService
  include Singleton

  NOTIFICATION_COOLDOWN = 15.minutes
  OCCURRENCE_WINDOW = 24.hours
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
    occurrence_count = increment_occurrence_count(key)
    return if Rails.cache.exist?(key)

    Rails.cache.write(key, true, expires_in: NOTIFICATION_COOLDOWN)
    notify_by_slack(error, safe_context) if ENV["SLACK_WEBHOOK_URL"].present?
    root_cause = root_cause_for(error)
    ErrorAlertMailer.failure(
      error_class: error.class.name,
      error_summary: safe_error_summary(root_cause),
      root_cause_class: root_cause.class.name,
      application_frame: application_frame_for(error),
      release: release_identifier,
      occurrence_count: occurrence_count,
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

  def increment_occurrence_count(notification_key)
    count_key = "#{notification_key}/count"
    Rails.cache.increment(count_key, 1, initial: 0, expires_in: OCCURRENCE_WINDOW) || 1
  rescue
    1
  end

  def root_cause_for(error)
    current = error
    5.times do
      break unless current.cause && current.cause != current

      current = current.cause
    end
    current
  end

  def safe_error_summary(error)
    summary = error.message.to_s.lines.first.to_s.strip.truncate(300)
    summary.gsub!(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i, "[FILTERED_EMAIL]")
    summary.gsub!(/(?:\+?81[-\s]?)?0\d{1,4}[-\s]?\d{1,4}[-\s]?\d{3,4}/, "[FILTERED_PHONE]")
    summary.gsub!(/\b(password|token|secret|api[_-]?key)\b\s*[=:]\s*[^\s,;]+/i, "\\1=[FILTERED]")
    summary.presence || "詳細なし"
  end

  def application_frame_for(error)
    root = Rails.root.to_s
    frame = Array(error.backtrace).find { |line| line.start_with?(root) }
    frame&.delete_prefix("#{root}/") || "取得できませんでした"
  end

  def release_identifier
    ENV["HEROKU_RELEASE_VERSION"].presence || ENV["SOURCE_VERSION"].to_s.first(12).presence || "不明"
  end
end

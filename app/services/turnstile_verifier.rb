require "net/http"
require "json"

class TurnstileVerifier
  VERIFY_URL = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")

  def self.enabled?
    ENV["TURNSTILE_SITE_KEY"].present? && ENV["TURNSTILE_SECRET_KEY"].present?
  end

  def self.valid?(token:, remote_ip: nil)
    return true unless enabled?
    return false if token.blank?

    response = Net::HTTP.post_form(
      VERIFY_URL,
      secret: ENV.fetch("TURNSTILE_SECRET_KEY"),
      response: token,
      remoteip: remote_ip
    )

    response.is_a?(Net::HTTPSuccess) && JSON.parse(response.body)["success"] == true
  rescue JSON::ParserError, SocketError, SystemCallError, Timeout::Error => error
    Rails.logger.error("Turnstile verification failed: #{error.class}: #{error.message}")
    false
  end
end

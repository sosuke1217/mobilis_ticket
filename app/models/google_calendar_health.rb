class GoogleCalendarHealth < ApplicationRecord
  NOTIFICATION_COOLDOWN = 1.hour

  validates :key, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[unknown healthy failing] }

  def self.current
    find_or_create_by!(key: "default")
  end

  def self.record_success!
    health = current
    recovered = health.status == "failing"

    health.update!(
      status: "healthy",
      last_success_at: Time.current,
      last_error: nil
    )

    GoogleCalendarHealthMailer.recovered(health).deliver_later if recovered
    health
  rescue => e
    Rails.logger.error "❌ Failed to record Google Calendar recovery: #{e.message}"
    nil
  end

  def self.record_failure!(message)
    health = current
    notify = false

    health.with_lock do
      notify = health.last_failure_notified_at.nil? ||
               health.last_failure_notified_at < NOTIFICATION_COOLDOWN.ago

      attributes = {
        status: "failing",
        last_failure_at: Time.current,
        last_error: message.to_s.truncate(1000)
      }
      attributes[:last_failure_notified_at] = Time.current if notify
      health.update!(attributes)
    end

    GoogleCalendarHealthMailer.failure(health).deliver_later if notify
    health
  rescue => e
    Rails.logger.error "❌ Failed to record Google Calendar failure: #{e.message}"
    nil
  end
end

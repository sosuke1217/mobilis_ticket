class BookingHealthChecker
  REQUIRED_SETTING_FIELDS = %i[
    reservation_interval_minutes
    business_hours_start
    business_hours_end
    slot_interval_minutes
  ].freeze

  def self.healthy?
    new.healthy?
  end

  def healthy?
    ActiveRecord::Base.connection.select_value("SELECT 1")
    Reservation.limit(1).pick(:id)

    settings = ApplicationSetting.first
    raise ActiveRecord::RecordNotFound, "booking settings unavailable" unless settings
    raise ActiveRecord::RecordInvalid, settings unless settings.valid?
    raise ActiveRecord::RecordInvalid, settings if REQUIRED_SETTING_FIELDS.any? { |field| settings.public_send(field).blank? }

    true
  rescue StandardError => error
    Rails.logger.error("[BOOKING HEALTH] unavailable class=#{error.class.name}")
    false
  end
end

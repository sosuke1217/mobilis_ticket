class BusinessHoursSerializer
  def initialize(setting)
    @setting = setting
  end
  
  def as_json
    {
      id: @setting.id,
      business_hours: {
        start: @setting.business_hours_start,
        end: @setting.business_hours_end,
        formatted: @setting.formatted_business_hours,
        duration: @setting.business_hours_duration
      },
      fullcalendar_config: @setting.fullcalendar_business_hours,
      status: {
        currently_open: @setting.currently_open?,
        last_updated: @setting.updated_at.iso8601
      },
      metadata: {
        slot_interval: @setting.slot_interval_minutes,
        reservation_interval: @setting.reservation_interval_minutes,
        sunday_closed: @setting.sunday_closed?
      }
    }
  end
end 
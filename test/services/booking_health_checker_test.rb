require "test_helper"

class BookingHealthCheckerTest < ActiveSupport::TestCase
  test "is healthy when the database and booking settings are available" do
    ApplicationSetting.delete_all
    ApplicationSetting.create!(
      reservation_interval_minutes: 75,
      business_hours_start: 10,
      business_hours_end: 20,
      slot_interval_minutes: 30
    )

    assert BookingHealthChecker.healthy?
  end

  test "is unavailable when booking settings are missing" do
    ApplicationSetting.delete_all

    assert_not BookingHealthChecker.healthy?
  end
end

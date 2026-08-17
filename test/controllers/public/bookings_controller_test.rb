require "test_helper"

class Public::BookingsControllerTest < ActiveSupport::TestCase
  setup do
    @controller = Public::BookingsController.new
    @start_time = Time.zone.parse("2026-08-20 10:00")
    @end_time = Time.zone.parse("2026-08-20 11:00")
  end

  test "Google busy period blocks an overlapping booking slot" do
    busy_periods = [
      {
        start_time: Time.zone.parse("2026-08-20 10:30"),
        end_time: Time.zone.parse("2026-08-20 11:30")
      }
    ]

    available = @controller.send(
      :google_calendar_slot_available?,
      @start_time,
      @end_time,
      0,
      busy_periods
    )

    assert_not available
  end

  test "Google busy period outside the reservation buffer keeps slot available" do
    busy_periods = [
      {
        start_time: Time.zone.parse("2026-08-20 11:21"),
        end_time: Time.zone.parse("2026-08-20 12:00")
      }
    ]

    available = @controller.send(
      :google_calendar_slot_available?,
      @start_time,
      @end_time,
      20,
      busy_periods
    )

    assert available
  end

  test "empty Google busy periods keep slot available" do
    available = @controller.send(
      :google_calendar_slot_available?,
      @start_time,
      @end_time,
      20,
      []
    )

    assert available
  end
end

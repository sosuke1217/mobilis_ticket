require "test_helper"
require "ostruct"

class GoogleCalendarSyncTest < ActiveSupport::TestCase
  test "FreeBusy request uses DateTime values and an IANA time zone" do
    captured_request = nil
    calendar_service = Object.new
    calendar_service.define_singleton_method(:query_freebusy) do |request|
      captured_request = request
      OpenStruct.new(calendars: {})
    end

    sync = GoogleCalendarSync.allocate
    sync.instance_variable_set(:@service, calendar_service)
    sync.define_singleton_method(:authorized?) { true }

    periods = sync.busy_periods(
      start_time: Time.zone.parse("2026-08-20 00:00"),
      end_time: Time.zone.parse("2026-08-20 23:59")
    )

    assert_empty periods
    assert_instance_of DateTime, captured_request.time_min
    assert_instance_of DateTime, captured_request.time_max
    assert_equal "Asia/Tokyo", captured_request.time_zone
    assert_equal "primary", captured_request.items.first.id
  end
end

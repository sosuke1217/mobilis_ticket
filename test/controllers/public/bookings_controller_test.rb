require "test_helper"
require "ostruct"

class Public::BookingsControllerTest < ActiveSupport::TestCase
  setup do
    @controller = Public::BookingsController.new
    @start_time = Time.zone.parse("2026-08-20 10:00")
    @end_time = Time.zone.parse("2026-08-20 11:00")
  end

  test "existing customer is updated from the current booking form" do
    user = users(:one)
    user.update!(phone_number: "09012345678", email: nil, address: nil)

    submitted = ActionController::Parameters.new(
      name: "Updated Name",
      phone_number: "09012345678",
      email: "updated@example.com",
      address: "Updated Address"
    ).permit!

    @controller.define_singleton_method(:booking_params) { submitted }

    result = @controller.send(:find_or_create_user)

    assert_equal user.id, result.id
    assert_equal "updated@example.com", result.reload.email
    assert_equal "Updated Name", result.name
    assert_equal "Updated Address", result.address
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

  test "recent Google availability is used when a refresh temporarily fails" do
    date = Date.new(2026, 8, 20)
    periods = [{ start_time: @start_time, end_time: @end_time }]
    responses = [periods, nil]
    sync = Object.new
    sync.define_singleton_method(:busy_periods) { |**| responses.shift }
    cache = ActiveSupport::Cache::MemoryStore.new

    @controller.instance_variable_set(:@google_calendar_sync, sync)
    @controller.define_singleton_method(:google_calendar_enabled?) { true }
    @controller.define_singleton_method(:google_calendar_cache) { cache }

    assert_equal periods, @controller.send(:google_calendar_busy_periods_for, date)
    assert_equal periods, @controller.send(:google_calendar_busy_periods_for, date)
  end

  test "availability fails closed without a recent cache" do
    date = Date.new(2026, 8, 20)
    sync = Object.new
    sync.define_singleton_method(:busy_periods) { |**| nil }
    cache = ActiveSupport::Cache::MemoryStore.new

    @controller.instance_variable_set(:@google_calendar_sync, sync)
    @controller.define_singleton_method(:google_calendar_enabled?) { true }
    @controller.define_singleton_method(:google_calendar_cache) { cache }

    assert_nil @controller.send(:google_calendar_busy_periods_for, date)
  end

  test "final booking check rejects a booking when Google cannot be reached" do
    reservation = OpenStruct.new(start_time: @start_time, end_time: @end_time)
    sync = Object.new
    sync.define_singleton_method(:busy_periods) { |**| nil }
    @controller.instance_variable_set(:@google_calendar_sync, sync)
    @controller.define_singleton_method(:google_calendar_enabled?) { true }

    @controller.define_singleton_method(:google_calendar_interval_minutes) { 20 }

    assert_equal :unavailable, @controller.send(:google_calendar_booking_status, reservation)
  end

  test "final booking check rejects a live Google conflict" do
    reservation = OpenStruct.new(start_time: @start_time, end_time: @end_time)
    busy_start = @start_time + 30.minutes
    busy_end = @end_time + 30.minutes
    sync = Object.new
    sync.define_singleton_method(:busy_periods) do |**|
      [{ start_time: busy_start, end_time: busy_end }]
    end
    @controller.instance_variable_set(:@google_calendar_sync, sync)
    @controller.define_singleton_method(:google_calendar_enabled?) { true }

    @controller.define_singleton_method(:google_calendar_interval_minutes) { 20 }

    assert_equal :conflict, @controller.send(:google_calendar_booking_status, reservation)
  end
end

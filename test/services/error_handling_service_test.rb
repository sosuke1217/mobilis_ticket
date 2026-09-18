require "test_helper"

class ErrorHandlingServiceTest < ActiveSupport::TestCase
  setup do
    @perform_deliveries = ActionMailer::Base.perform_deliveries
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries.clear
    @cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    ActionMailer::Base.perform_deliveries = @perform_deliveries
  end

  test "email contains operational identifiers but excludes unsafe context" do
    Rails.stub(:cache, @cache) do
      error = NoMethodError.new("customer@example.com password=secret phone=090-1234-5678")
      error.set_backtrace(["#{Rails.root}/app/views/public/bookings/new.html.erb:12"])
      ErrorHandlingService.log_error(
        error,
        source: "public_booking#create",
        request_id: "request-123",
        reservation_id: 42,
        email: "customer@example.com",
        phone_number: "09012345678"
      )
    end

    message = ActionMailer::Base.deliveries.last
    assert_includes message.body.encoded, "public_booking#create"
    assert_includes message.body.encoded, "request-123"
    assert_includes message.body.encoded, "reservation_id: 42"
    assert_includes message.body.encoded, "NoMethodError"
    assert_includes message.body.encoded, "app/views/public/bookings/new.html.erb:12"
    assert_includes message.body.encoded, "同一エラー発生回数（24時間）: 1"
    assert_includes message.body.encoded, "[FILTERED_EMAIL]"
    assert_includes message.body.encoded, "[FILTERED_PHONE]"
    assert_includes message.body.encoded, "password=[FILTERED]"
    assert_not_includes message.body.encoded, "customer@example.com"
    assert_not_includes message.body.encoded, "09012345678"
    assert_not_includes message.body.encoded, "password=secret"
  end

  test "same error source sends only one email during cooldown" do
    Rails.stub(:cache, @cache) do
      2.times do
        ErrorHandlingService.log_error(
          RuntimeError.new("different details"),
          source: "line#booking_confirmed",
          reservation_id: 42
        )
      end
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
  end
end

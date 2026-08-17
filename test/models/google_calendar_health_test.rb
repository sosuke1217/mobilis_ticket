require "test_helper"

class GoogleCalendarHealthTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    GoogleCalendarHealth.delete_all
    clear_enqueued_jobs
  end

  test "failure notification is limited to once per hour" do
    assert_enqueued_emails 1 do
      GoogleCalendarHealth.record_failure!("invalid_grant")
      GoogleCalendarHealth.record_failure!("invalid_grant")
    end

    health = GoogleCalendarHealth.current
    assert_equal "failing", health.status
    assert_equal "invalid_grant", health.last_error
    assert_not_nil health.last_failure_at
    assert_not_nil health.last_failure_notified_at
  end

  test "recovery sends one notification and records the last success" do
    GoogleCalendarHealth.record_failure!("temporary failure")
    clear_enqueued_jobs

    assert_enqueued_emails 1 do
      GoogleCalendarHealth.record_success!
      GoogleCalendarHealth.record_success!
    end

    health = GoogleCalendarHealth.current
    assert_equal "healthy", health.status
    assert_nil health.last_error
    assert_not_nil health.last_success_at
  end
end

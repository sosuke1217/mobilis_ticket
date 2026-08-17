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

  test "authorization URL uses the registered web callback and state" do
    captured = nil
    authorizer = Object.new
    authorizer.define_singleton_method(:get_authorization_url) do |**options|
      captured = options
      "https://accounts.google.com/o/oauth2/auth"
    end

    File.stub(:exist?, true) do
      Google::Auth::ClientId.stub(:from_file, Object.new) do
        GoogleAuthStores::DatabaseTokenStore.stub(:new, Object.new) do
          Google::Auth::UserAuthorizer.stub(:new, authorizer) do
            url = GoogleCalendarSync.get_authorization_url(
              base_url: "https://example.com/admin/google_calendar/callback",
              state: "secure-state"
            )

            assert_equal "https://accounts.google.com/o/oauth2/auth", url
          end
        end
      end
    end

    assert_equal "https://example.com/admin/google_calendar/callback", captured[:base_url]
    assert_equal "secure-state", captured[:state]
  end

  test "authorization code exchange uses the same web callback" do
    captured = nil
    credentials = Object.new
    authorizer = Object.new
    authorizer.define_singleton_method(:get_and_store_credentials_from_code) do |**options|
      captured = options
      credentials
    end

    File.stub(:exist?, true) do
      Google::Auth::ClientId.stub(:from_file, Object.new) do
        GoogleAuthStores::DatabaseTokenStore.stub(:new, Object.new) do
          Google::Auth::UserAuthorizer.stub(:new, authorizer) do
            result = GoogleCalendarSync.authorize_with_code(
              "authorization-code",
              base_url: "https://example.com/admin/google_calendar/callback"
            )

            assert_same credentials, result
          end
        end
      end
    end

    assert_equal "default", captured[:user_id]
    assert_equal "authorization-code", captured[:code]
    assert_equal "https://example.com/admin/google_calendar/callback", captured[:base_url]
  end
end

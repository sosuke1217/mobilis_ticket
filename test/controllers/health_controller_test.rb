require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "booking health endpoint returns only a safe success status" do
    BookingHealthChecker.stub(:healthy?, true) do
      get "/health/booking"
    end

    assert_response :success
    assert_equal({ "status" => "ok" }, response.parsed_body)
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "booking health endpoint returns 503 without internal details" do
    BookingHealthChecker.stub(:healthy?, false) do
      get "/health/booking"
    end

    assert_response :service_unavailable
    assert_equal({ "status" => "unavailable" }, response.parsed_body)
  end
end

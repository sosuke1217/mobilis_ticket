require "test_helper"
require Rails.root.join("lib/middleware/rate_limiter")

class RateLimiterTest < ActiveSupport::TestCase
  test "public booking creation is limited to five attempts per ten minutes" do
    app = ->(_env) { [200, { "Content-Type" => "text/plain" }, ["ok"]] }
    store = ActiveSupport::Cache::MemoryStore.new
    limiter = RateLimiter.new(app)

    Rails.stub(:cache, store) do
      5.times do
        response = Rack::MockRequest.new(limiter).post(
          "/public/bookings",
          "REMOTE_ADDR" => "203.0.113.10",
          "HTTP_ACCEPT" => "text/html"
        )
        assert_equal 200, response.status
      end

      blocked = Rack::MockRequest.new(limiter).post(
        "/public/bookings",
        "REMOTE_ADDR" => "203.0.113.10",
        "HTTP_ACCEPT" => "text/html"
      )

      assert_equal 429, blocked.status
      assert_equal "600", blocked["Retry-After"]
      assert_includes blocked.body, "10分ほど待って"
    end
  end

  test "different IP addresses have independent limits" do
    app = ->(_env) { [200, { "Content-Type" => "text/plain" }, ["ok"]] }
    store = ActiveSupport::Cache::MemoryStore.new
    limiter = RateLimiter.new(app)

    Rails.stub(:cache, store) do
      5.times do
        Rack::MockRequest.new(limiter).post("/public/bookings", "REMOTE_ADDR" => "203.0.113.10")
      end

      response = Rack::MockRequest.new(limiter).post(
        "/public/bookings",
        "REMOTE_ADDR" => "203.0.113.11"
      )

      assert_equal 200, response.status
    end
  end
end

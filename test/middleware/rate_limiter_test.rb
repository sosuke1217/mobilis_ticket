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

  test "admin login is limited and a successful login can reset its counter" do
    app = ->(_env) { [200, { "Content-Type" => "text/plain" }, ["ok"]] }
    store = ActiveSupport::Cache::MemoryStore.new
    limiter = RateLimiter.new(app)
    request = Rack::MockRequest.new(limiter)
    ip = "203.0.113.20"

    Rails.stub(:cache, store) do
      5.times do
        assert_equal 200, request.post("/admin_users/sign_in", "REMOTE_ADDR" => ip).status
      end
      assert_equal 429, request.post("/admin_users/sign_in", "REMOTE_ADDR" => ip).status

      RateLimiter.reset!("admin_login", ip)

      assert_equal 200, request.post("/admin_users/sign_in", "REMOTE_ADDR" => ip).status
    end
  end
end

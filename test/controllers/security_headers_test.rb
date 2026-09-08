require "test_helper"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "CSP permits Cloudflare Turnstile resources" do
    get new_public_booking_path

    assert_response :success

    policy = response.headers.fetch("Content-Security-Policy")
    assert_includes policy, "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://challenges.cloudflare.com"
    assert_includes policy, "connect-src 'self' https://challenges.cloudflare.com"
    assert_includes policy, "frame-src https://challenges.cloudflare.com"
  end
end

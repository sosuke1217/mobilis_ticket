require "test_helper"

class TurnstileVerifierTest < ActiveSupport::TestCase
  test "verification is disabled until both keys are configured" do
    ENV.stub(:[], nil) do
      assert_not TurnstileVerifier.enabled?
      assert TurnstileVerifier.valid?(token: nil)
    end
  end

  test "missing token is rejected when Turnstile is enabled" do
    values = {
      "TURNSTILE_SITE_KEY" => "site-key",
      "TURNSTILE_SECRET_KEY" => "secret-key"
    }

    ENV.stub(:[], ->(key) { values[key] }) do
      assert TurnstileVerifier.enabled?
      assert_not TurnstileVerifier.valid?(token: "")
    end
  end
end

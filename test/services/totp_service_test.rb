require "test_helper"

class TotpServiceTest < ActiveSupport::TestCase
  test "generated code is accepted within the current time window" do
    secret = TotpService.generate_secret
    time = Time.zone.parse("2026-09-08 12:00:00")
    code = TotpService.generate_code(secret, time.to_i / TotpService::INTERVAL)

    assert TotpService.valid?(secret, code, at: time)
    assert_not TotpService.valid?(secret, "000000", at: time) unless code == "000000"
  end

  test "provisioning URI identifies Mobilis and the admin account" do
    uri = TotpService.provisioning_uri(secret: "ABC234", account: "admin@example.com")

    assert_includes uri, "otpauth://totp/Mobilis%3Aadmin%40example.com"
    assert_includes uri, "secret=ABC234"
  end
end

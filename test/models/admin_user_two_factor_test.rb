require "test_helper"

class AdminUserTwoFactorTest < ActiveSupport::TestCase
  test "OTP secret is encrypted and backup codes are single use" do
    admin = AdminUser.create!(
      email: "two-factor-admin@example.com",
      password: "ValidPassword123!"
    )
    secret = TotpService.generate_secret
    admin.otp_secret = secret
    codes = admin.generate_backup_codes
    admin.save!

    assert_equal secret, admin.reload.otp_secret
    assert_not_includes admin.otp_secret_ciphertext, secret
    assert admin.consume_backup_code(codes.first)
    assert_not admin.consume_backup_code(codes.first)
  end
end

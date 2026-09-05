require "test_helper"

class Public::BookingsHelperTest < ActionView::TestCase
  test "email address is masked on the public booking page" do
    assert_equal "c***@example.com", masked_email("customer@example.com")
    assert_equal "a***@example.com", masked_email("a@example.com")
  end

  test "missing or invalid email is not exposed" do
    assert_equal "未登録 / Not available", masked_email(nil)
    assert_equal "未登録 / Not available", masked_email("invalid")
  end
end

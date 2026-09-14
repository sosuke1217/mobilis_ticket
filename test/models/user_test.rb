require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "phone matching key ignores formatting and full-width digits" do
    assert_equal "09012345678", User.phone_matching_key("０９０ １２３４-５６７８")
  end

  test "accepts and normalizes a Japanese international phone number" do
    user = User.new(name: "Test User", phone_number: "＋８１ ９０ー１２３４ー５６７８")

    assert user.valid?
    assert_equal "+81 90-1234-5678", user.phone_number
  end

  test "accepts a domestic phone number with hyphens" do
    user = User.new(name: "Test User", phone_number: "090-1234-5678")

    assert user.valid?
  end

  test "rejects letters in a phone number" do
    user = User.new(name: "Test User", phone_number: "090-ABCD-5678")

    assert_not user.valid?
    assert user.errors.added?(:phone_number, :invalid, value: "090-ABCD-5678")
  end
  # test "the truth" do
  #   assert true
  # end
end

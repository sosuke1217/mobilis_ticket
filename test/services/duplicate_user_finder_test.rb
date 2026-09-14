require "test_helper"

class DuplicateUserFinderTest < ActiveSupport::TestCase
  test "finds customers whose formatted phone numbers are equal" do
    left = User.create!(name: "Left", phone_number: "090-1234-5678")
    right = User.create!(name: "Right", phone_number: "０９０ １２３４ ５６７８")

    candidate = DuplicateUserFinder.call(User.where(id: [left.id, right.id])).first

    assert_equal [left.id, right.id], candidate[:users].map(&:id)
    assert_equal ["電話番号"], candidate[:reasons]
  end

  test "does not use names alone as a duplicate signal" do
    left = User.create!(name: "Same Name", phone_number: "09011112222")
    right = User.create!(name: "Same Name", phone_number: "09033334444")

    assert_empty DuplicateUserFinder.call(User.where(id: [left.id, right.id]))
  end
end

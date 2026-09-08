require "test_helper"

class SensitiveParameterFilterTest < ActiveSupport::TestCase
  test "filters booking personal information and authentication secrets" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    input = {
      name: "Test Person",
      phone_number: "09012345678",
      email: "person@example.com",
      address: "Tokyo",
      access_method: "Door code 1234",
      note: "Private note",
      password: "Secret1!",
      otp: "123456",
      backup_code: "ABC123"
    }

    filtered = filter.filter(input)

    input.each_key do |key|
      assert_equal "[FILTERED]", filtered[key], "expected #{key} to be filtered"
    end
  end

  test "keeps operational identifiers visible" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter(reservation_id: 123, status: "confirmed")

    assert_equal 123, filtered[:reservation_id]
    assert_equal "confirmed", filtered[:status]
  end
end

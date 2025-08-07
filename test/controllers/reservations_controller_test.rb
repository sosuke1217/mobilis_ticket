require "test_helper"

class ReservationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_reservation_url
    assert_response :success
  end

  test "should get create" do
    post reservations_url
    assert_response :success
  end
end

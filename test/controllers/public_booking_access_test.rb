require "test_helper"

class PublicBookingAccessTest < ActionDispatch::IntegrationTest
  setup do
    @reservation = reservations(:one)
    @reservation.update_columns(
      start_time: 2.days.from_now.change(min: 0),
      end_time: 2.days.from_now.change(min: 0) + 60.minutes,
      status: Reservation.statuses[:tentative]
    )
  end

  test "numeric reservation id cannot open the public page" do
    get public_booking_path(@reservation.id)

    assert_redirected_to new_public_booking_path
  end

  test "signed token opens the matching public reservation" do
    get public_booking_path(@reservation.public_access_token)

    assert_response :success
  end

  test "cancel rejects a numeric reservation id" do
    post cancel_public_booking_path(@reservation.id)
    assert_redirected_to new_public_booking_path
    assert @reservation.reload.tentative?
  end
end

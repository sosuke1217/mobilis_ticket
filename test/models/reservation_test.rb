require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  test "initial assessment uses the configured price" do
    reservation = Reservation.new(course: "初回評価セッション")

    assert_equal 11_000, reservation.get_price
    assert_equal Reservation.price_for("初回評価セッション"), reservation.get_price
  end

  test "public booking course prices use the same source of truth" do
    controller = Public::BookingsController.new
    courses = controller.send(:load_courses)

    courses.each do |course|
      reservation = Reservation.new(course: course[:name])
      assert_equal course[:price], reservation.get_price
    end
  end

  test "public access token resolves only with the correct signature" do
    reservation = Reservation.new(name: "Token Test", course: "初回評価セッション")
    reservation.save!(validate: false)
    token = reservation.public_access_token

    assert_equal reservation, Reservation.find_by_public_access_token(token)
    assert_nil Reservation.find_by_public_access_token("#{token}tampered")
    assert_nil Reservation.find_by_public_access_token(reservation.id.to_s)
  end

  # test "the truth" do
  #   assert true
  # end
end

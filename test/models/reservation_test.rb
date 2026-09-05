require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  test "initial assessment uses the configured price" do
    reservation = Reservation.new(course: "初回評価セッション")

    assert_equal 11_000, reservation.get_price
    assert_equal ApplicationConfig::COURSE_PRICES.fetch("初回評価セッション"), reservation.get_price
  end

  test "public booking course prices use the same source of truth" do
    controller = Public::BookingsController.new
    courses = controller.send(:load_courses)

    courses.each do |course|
      reservation = Reservation.new(course: course[:name])
      assert_equal course[:price], reservation.get_price
    end
  end

  # test "the truth" do
  #   assert true
  # end
end

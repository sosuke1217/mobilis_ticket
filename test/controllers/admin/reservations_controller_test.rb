require "test_helper"
require "ostruct"

class Admin::ReservationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @reservations_controller = Admin::ReservationsController.new
  end

  test "confirmation update does not also send reservation changed email" do
    reservation = notification_reservation(
      "status" => ["tentative", "confirmed"],
      "start_time" => [1.day.from_now, 2.days.from_now]
    )
    mailer_called = false

    ReservationMailer.stub(:reservation_updated, ->(*) { mailer_called = true }) do
      @reservations_controller.send(:send_change_notification, reservation, {})
    end

    assert_not mailer_called
  end

  test "time-only update still sends reservation changed email" do
    reservation = notification_reservation(
      "start_time" => [1.day.from_now, 2.days.from_now]
    )
    delivery = Object.new
    delivered = false
    delivery.define_singleton_method(:deliver_now) { delivered = true }

    ReservationMailer.stub(:reservation_updated, delivery) do
      @reservations_controller.send(:send_change_notification, reservation, {})
    end

    assert delivered
  end

  private

  def notification_reservation(saved_changes)
    reservation = Object.new
    reservation.define_singleton_method(:saved_changes) { saved_changes }
    reservation.define_singleton_method(:saved_change_to_status?) { saved_changes.key?("status") }
    reservation.define_singleton_method(:confirmed?) { true }
    reservation.define_singleton_method(:cancelled?) { false }
    reservation.define_singleton_method(:user) { OpenStruct.new(email: "customer@example.com") }
    reservation.define_singleton_method(:id) { 123 }
    reservation
  end
end

require "test_helper"

class ReservationMailerTest < ActionMailer::TestCase
  setup do
    @user = User.new(name: "テストユーザー", email: "customer@example.jp")
    @attributes = {
      user: @user,
      start_time: Time.zone.parse("2026-08-20 10:00"),
      end_time: Time.zone.parse("2026-08-20 11:00"),
      course: "60分"
    }
  end

  test "tentative reservation is described as a booking request" do
    reservation = Reservation.new(**@attributes, status: :tentative)

    mail = ReservationMailer.confirmation(reservation)

    assert_includes mail.subject, "仮予約を受け付けました"
    assert_includes mail.html_part.body.decoded, "現在はまだ予約確定前です"
  end

  test "confirmed reservation is described as confirmed" do
    reservation = Reservation.new(**@attributes, status: :confirmed)

    mail = ReservationMailer.confirmation(reservation)

    assert_includes mail.subject, "ご予約確定"
    assert_includes mail.html_part.body.decoded, "ご予約が確定しました"
  end
end

require "test_helper"

class AdminMailerTest < ActionMailer::TestCase
  test "new booking request includes customer and reservation details" do
    user = User.new(
      name: "山田太郎",
      email: "customer@example.com",
      phone_number: "09012345678",
      address: "東京都港区"
    )
    reservation = Reservation.new(
      user: user,
      status: :tentative,
      start_time: Time.zone.parse("2026-08-20 10:00"),
      end_time: Time.zone.parse("2026-08-20 11:00"),
      course: "60分",
      note: "テスト予約"
    )

    mail = AdminMailer.new_booking_request(reservation)

    assert_equal [ENV.fetch("ADMIN_EMAIL", "admin@mobilis-stretch.com")], mail.to
    assert_includes mail.subject, "新規仮予約"
    assert_includes mail.body.decoded, "山田太郎"
    assert_includes mail.body.decoded, "09012345678"
    assert_includes mail.body.decoded, "管理画面で予約内容を確認"
  end
end

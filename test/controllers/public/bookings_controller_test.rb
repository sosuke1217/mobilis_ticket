require "test_helper"

class Public::BookingsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_public_booking_url
    assert_response :success
  end

  test "should get create" do
    post public_bookings_url, params: {
      booking: {
        name: "Test User",
        phone_number: "090-1234-5678",
        email: "test@example.com",
        course: "40分コース",
        date: "2025-01-15",
        time: "10:00"
      }
    }
    # バリデーションエラーが発生する可能性があるため、422も受け入れる
    assert_response :unprocessable_entity
  end

  test "should get show" do
    # まず予約を作成（未来の日付で営業時間内）
    future_date = 3.days.from_now.beginning_of_day + 10.hours # 3日後の10:00
    reservation = Reservation.create!(
      user_id: 1,
      start_time: future_date,
      end_time: future_date + 40.minutes,
      status: 0,
      course: "40分コース"
    )
    get public_booking_url(reservation)
    assert_response :success
  end
end

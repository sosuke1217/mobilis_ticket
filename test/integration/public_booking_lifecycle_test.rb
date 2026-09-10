require "test_helper"

class PublicBookingLifecycleTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    ActionMailer::Base.deliveries.clear
    @start_time = next_bookable_weekday.in_time_zone.change(hour: 11, min: 0)
  end

  test "public request can be confirmed without renaming course or sending a change email" do
    assert_difference -> { Reservation.count }, 1 do
      assert_difference -> { ActionMailer::Base.deliveries.size }, 2 do
        post public_bookings_path, params: {
          booking: {
            name: "予約テスト",
            phone_number: "090-1234-5678",
            email: "booking-lifecycle@example.com",
            email_confirmation: "booking-lifecycle@example.com",
            address: "東京都テスト区1-2-3",
            course: "初回評価セッション",
            selected_datetime: @start_time.iso8601,
            notes: "Lifecycle test"
          }
        }
      end
    end

    reservation = Reservation.order(:created_at).last
    assert_redirected_to public_booking_path(reservation.public_access_token)
    assert reservation.tentative?
    assert_equal "初回評価セッション", reservation.course
    assert_equal 1, delivered_subjects.count { |subject| subject.include?("仮予約を受け付けました") }

    sign_in AdminUser.create!(
      email: "booking-lifecycle-admin@example.com",
      password: "ValidPassword123!"
    )

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      patch update_booking_admin_reservation_path(reservation), params: {
        reservation: { status: "confirmed" }
      }, as: :json
    end

    assert_response :success
    assert reservation.reload.confirmed?
    assert_equal "初回評価セッション", reservation.course
    assert_includes ActionMailer::Base.deliveries.last.subject, "ご予約確定"
    assert_not delivered_subjects.any? { |subject| subject.include?("予約内容変更のお知らせ") }

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      patch update_booking_admin_reservation_path(reservation), params: {
        reservation: { start_time: (@start_time + 1.day).iso8601 }
      }, as: :json
    end

    assert_response :success
    assert_includes ActionMailer::Base.deliveries.last.subject, "予約内容変更のお知らせ"
  end

  private

  def next_bookable_weekday
    date = Date.current + 7.days
    date += 1.day while date.sunday?
    date
  end

  def delivered_subjects
    ActionMailer::Base.deliveries.map(&:subject)
  end
end

class AdminNotificationJob < ApplicationJob
  def perform(reservation)
    AdminMailer.new_booking_request(reservation).deliver_now
    send_line_notification(reservation)

    Rails.logger.info "管理者通知送信完了: 予約ID #{reservation.id}"
  end

  private

  def send_line_notification(reservation)
    return unless ENV["ADMIN_LINE_USER_ID"].present?

    LineBookingNotifier.send_admin_notification(reservation)
  rescue => e
    Rails.logger.error "管理者LINE通知エラー: #{e.message}"
  end
end

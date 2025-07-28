# app/jobs/admin_notification_job.rb
class AdminNotificationJob < ApplicationJob
  def perform(reservation)
    # 管理者へのSlack通知
    send_slack_notification(reservation) if Rails.env.production?
    
    # 管理者へのメール通知
    AdminMailer.new_booking_request(reservation).deliver_now
    
    Rails.logger.info "管理者通知送信完了: 予約ID #{reservation.id}"
  end

  private

  def send_slack_notification(reservation)
    # Slack webhook実装（必要に応じて）
  end
end

# app/mailers/admin_mailer.rb
class AdminMailer < ApplicationMailer
  def new_booking_request(reservation)
    @reservation = reservation
    @user = reservation.user
    
    mail(
      to: ENV.fetch('ADMIN_EMAIL', 'admin@mobilis-stretch.com'),
      subject: "【新規予約】#{@user.name}様からの予約リクエスト"
    )
  end
end
# app/mailers/reservation_mailer.rb

class ReservationMailer < ApplicationMailer
  default from: ENV.fetch('MAIL_FROM', 'noreply@mobilis-stretch.com')

  def confirmation(reservation)
    @reservation = reservation
    @user = reservation.user
    @salon_name = "Mobilis Stretch"
    
    mail(
      to: @user.email,
      subject: "【#{@salon_name}】ご予約確認 - #{@reservation.start_time.strftime('%m/%d %H:%M')}"
    )
  end

  def reminder(reservation)
    @reservation = reservation
    @user = reservation.user
    @salon_name = "Mobilis Stretch"
    
    mail(
      to: @user.email,
      subject: "【#{@salon_name}】明日のご予約について - #{@reservation.start_time.strftime('%m/%d %H:%M')}"
    )
  end

  def cancellation_notification(reservation)
    @reservation = reservation
    @user = reservation.user
    @salon_name = "Mobilis Stretch"
    
    mail(
      to: @user.email,
      subject: "【#{@salon_name}】予約キャンセルのお知らせ - #{@reservation.start_time.strftime('%m/%d %H:%M')}"
    )
  end

  def completion_notification(reservation)
    @reservation = reservation
    @user = reservation.user
    @salon_name = "Mobilis Stretch"
    
    mail(
      to: @user.email,
      subject: "【#{@salon_name}】本日はありがとうございました"
    )
  end
end
# app/mailers/reservation_mailer.rb

class ReservationMailer < ApplicationMailer
  default from: ENV.fetch('MAIL_FROM', 'noreply@mobilis-stretch.com')

  def confirmation(reservation)
    @reservation = reservation
    @user = reservation.user
    @salon_name = "Mobilis Stretch"
    @tentative = reservation.tentative?
    
    # ユーザーの言語設定を判定（デフォルトは日本語）
    user_language = detect_user_language(@user)
    
    # 件名を言語に応じて設定
    subject = case user_language
    when :en
      status_text = @tentative ? "Booking Request Received" : "Reservation Confirmed"
      "[#{@salon_name}] #{status_text} - #{@reservation.start_time.strftime('%m/%d %H:%M')}"
    else
      status_text = @tentative ? "仮予約を受け付けました" : "ご予約確定"
      "【#{@salon_name}】#{status_text} - #{@reservation.start_time.strftime('%m/%d %H:%M')}"
    end
    
    mail(
      to: @user.email,
      subject: subject,
      locale: user_language
    )
  end

  def reminder(reservation)
    @reservation = reservation
    @user = reservation.user
    @salon_name = "Mobilis Stretch"
    
    # ユーザーの言語設定を判定
    user_language = detect_user_language(@user)
    
    # 件名を言語に応じて設定
    subject = case user_language
    when :en
      "[#{@salon_name}] Tomorrow's Reservation - #{@reservation.start_time.strftime('%m/%d %H:%M')}"
    else
      "【#{@salon_name}】明日のご予約について - #{@reservation.start_time.strftime('%m/%d %H:%M')}"
    end
    
    mail(
      to: @user.email,
      subject: subject,
      locale: user_language
    )
  end

  def reservation_updated(reservation, previous_details)
    @reservation = reservation
    @previous_details = previous_details.with_indifferent_access
    @user = reservation.user
    @salon_name = "Mobilis Stretch"

    user_language = detect_user_language(@user)
    subject = if user_language == :en
      "[#{@salon_name}] Reservation Updated - #{@reservation.start_time.strftime('%m/%d %H:%M')}"
    else
      "【#{@salon_name}】予約内容変更のお知らせ - #{@reservation.start_time.strftime('%m/%d %H:%M')}"
    end

    mail(to: @user.email, subject: subject, locale: user_language)
  end

  def cancellation_notification(reservation)
    @reservation = reservation
    @user = reservation.user
    @salon_name = "Mobilis Stretch"
    
    # ユーザーの言語設定を判定
    user_language = detect_user_language(@user)
    
    # 件名を言語に応じて設定
    subject = case user_language
    when :en
      "[#{@salon_name}] Reservation Cancellation - #{@reservation.start_time.strftime('%m/%d %H:%M')}"
    else
      "【#{@salon_name}】予約キャンセルのお知らせ - #{@reservation.start_time.strftime('%m/%d %H:%M')}"
    end
    
    mail(
      to: @user.email,
      subject: subject,
      locale: user_language
    )
  end


  
  private
  
  # ユーザーの言語設定を判定するメソッド
  def detect_user_language(user)
    # 名前が英字のみの場合は英語、それ以外は日本語。
    # Gmailなどのドメインは言語を表さないため判定には使用しない。
    return :en if user.name&.match?(/\A[a-zA-Z\s]+\z/)
    
    :ja
  end
end
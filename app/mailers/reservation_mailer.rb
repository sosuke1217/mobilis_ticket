# app/mailers/reservation_mailer.rb

class ReservationMailer < ApplicationMailer
  default from: ENV.fetch('MAIL_FROM', 'noreply@mobilis-stretch.com')

  def confirmation(reservation)
    @reservation = reservation
    @user = reservation.user
    @salon_name = "Mobilis Stretch"
    
    # ユーザーの言語設定を判定（デフォルトは日本語）
    user_language = detect_user_language(@user)
    
    # 件名を言語に応じて設定
    subject = case user_language
    when :en
      "[#{@salon_name}] Reservation Confirmation - #{@reservation.start_time.strftime('%m/%d %H:%M')}"
    else
      "【#{@salon_name}】ご予約確認 - #{@reservation.start_time.strftime('%m/%d %H:%M')}"
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
    # メールアドレスのドメインで言語を判定
    return :en if user.email&.include?('.com') || user.email&.include?('.org') || user.email&.include?('.net')
    
    # 名前の文字種で言語を判定（簡易判定）
    return :en if user.name&.match?(/\A[a-zA-Z\s]+\z/)
    
    # デフォルトは日本語
    :ja
  end
end
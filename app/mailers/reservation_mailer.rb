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

# app/views/reservation_mailer/confirmation.html.erb
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>予約確認</title>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #007bff; color: white; padding: 20px; text-align: center; }
    .content { padding: 20px; background: #f8f9fa; }
    .reservation-details { background: white; padding: 15px; border-radius: 5px; margin: 15px 0; }
    .footer { padding: 20px; text-align: center; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1><%= @salon_name %></h1>
      <h2>ご予約確認</h2>
    </div>
    
    <div class="content">
      <p><%= @user.name %> 様</p>
      
      <p>いつもご利用いただきありがとうございます。<br>
      以下の内容でご予約を承りました。</p>
      
      <div class="reservation-details">
        <h3>📅 予約詳細</h3>
        <p><strong>日時：</strong><%= @reservation.start_time.strftime('%Y年%m月%d日 %H:%M') %> ～ <%= @reservation.end_time.strftime('%H:%M') %></p>
        <p><strong>コース：</strong><%= @reservation.course %></p>
        <p><strong>ステータス：</strong><%= @reservation.status_text %></p>
        <% if @reservation.note.present? %>
          <p><strong>備考：</strong><%= @reservation.note %></p>
        <% end %>
      </div>
      
      <p>ご不明な点がございましたら、お気軽にお問い合わせください。<br>
      当日お会いできることを楽しみにしております。</p>
    </div>
    
    <div class="footer">
      <p><%= @salon_name %><br>
      TEL: 03-1234-5678<br>
      Email: info@mobilis-stretch.com</p>
    </div>
  </div>
</body>
</html>

# app/views/reservation_mailer/cancellation_notification.html.erb
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>予約キャンセル</title>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #dc3545; color: white; padding: 20px; text-align: center; }
    .content { padding: 20px; background: #f8f9fa; }
    .cancellation-details { background: white; padding: 15px; border-radius: 5px; margin: 15px 0; border-left: 4px solid #dc3545; }
    .footer { padding: 20px; text-align: center; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1><%= @salon_name %></h1>
      <h2>予約キャンセルのお知らせ</h2>
    </div>
    
    <div class="content">
      <p><%= @user.name %> 様</p>
      
      <p>以下のご予約がキャンセルされました。</p>
      
      <div class="cancellation-details">
        <h3>❌ キャンセルされた予約</h3>
        <p><strong>日時：</strong><%= @reservation.start_time.strftime('%Y年%m月%d日 %H:%M') %> ～ <%= @reservation.end_time.strftime('%H:%M') %></p>
        <p><strong>コース：</strong><%= @reservation.course %></p>
        <p><strong>キャンセル日時：</strong><%= @reservation.cancelled_at.strftime('%Y年%m月%d日 %H:%M') %></p>
        <% if @reservation.cancellation_reason.present? %>
          <p><strong>理由：</strong><%= @reservation.cancellation_reason %></p>
        <% end %>
      </div>
      
      <p>またのご利用をお待ちしております。<br>
      ご不明な点がございましたら、お気軽にお問い合わせください。</p>
    </div>
    
    <div class="footer">
      <p><%= @salon_name %><br>
      TEL: 03-1234-5678<br>
      Email: info@mobilis-stretch.com</p>
    </div>
  </div>
</body>
</html>
namespace :mail do
  desc "Send test email to verify configuration"
  task test: :environment do
    puts "Testing email configuration..."
    
    begin
      # テストユーザーを作成または取得
      user = User.first || User.create!(
        name: "テストユーザー",
        email: "test@example.com"
      )
      
      # テスト予約を作成
      reservation = Reservation.create!(
        name: user.name,
        start_time: 1.day.from_now,
        end_time: 1.day.from_now + 1.hour,
        course: "60分",
        status: :confirmed,
        user: user
      )
      
      # メール送信テスト
      ReservationMailer.confirmation(reservation).deliver_now
      puts "✅ Test email sent successfully!"
      
    rescue => e
      puts "❌ Email test failed: #{e.message}"
      puts e.backtrace.first(5)
    end
  end
end
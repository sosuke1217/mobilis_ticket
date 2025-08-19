# lib/tasks/test_notifications.rake
# 通知機能のテスト用タスク

namespace :notifications do
  desc "通知機能の設定をテスト"
  task test_config: :environment do
    puts "🔔 通知機能設定テスト開始"
    puts "=" * 50
    
    # 環境変数チェック
    puts "📧 Gmail設定:"
    puts "  GMAIL_USERNAME: #{ENV['GMAIL_USERNAME'] || '未設定'}"
    puts "  GMAIL_APP_PASSWORD: #{ENV['GMAIL_APP_PASSWORD'] ? '設定済み' : '未設定'}"
    
    puts "\n📱 LINE Bot設定:"
    puts "  LINE_CHANNEL_SECRET: #{ENV['LINE_CHANNEL_SECRET'] ? '設定済み' : '未設定'}"
    puts "  LINE_CHANNEL_TOKEN: #{ENV['LINE_CHANNEL_TOKEN'] ? '設定済み' : '未設定'}"
    
    puts "\n⚙️ アプリケーション設定:"
    puts "  ADMIN_EMAIL: #{ENV['ADMIN_EMAIL'] || '未設定'}"
    puts "  MAIL_FROM: #{ENV['MAIL_FROM'] || '未設定'}"
    
    puts "\n📊 データベース状態:"
    puts "  通知設定: #{NotificationPreference.count}件"
    puts "  LINE連携ユーザー: #{User.where.not(line_user_id: nil).count}件"
    puts "  通知ログ: #{NotificationLog.count}件"
    
    puts "\n🔍 設定状況:"
    
    # Gmail設定チェック
    if ENV['GMAIL_USERNAME'] && ENV['GMAIL_APP_PASSWORD']
      puts "  ✅ Gmail設定: 完了"
    else
      puts "  ❌ Gmail設定: 未完了"
    end
    
    # LINE Bot設定チェック
    if ENV['LINE_CHANNEL_SECRET'] && ENV['LINE_CHANNEL_TOKEN']
      puts "  ✅ LINE Bot設定: 完了"
    else
      puts "  ❌ LINE Bot設定: 未完了"
    end
    
    puts "\n" + "=" * 50
    puts "テスト完了"
  end
  
  desc "メール通知のテスト送信"
  task test_email: :environment do
    puts "📧 メール通知テスト開始"
    
    # テスト用のユーザーを取得
    user = User.first
    if user.nil?
      puts "❌ テスト用のユーザーが見つかりません"
      next
    end
    
    # テスト用の予約を作成
    reservation = Reservation.new(
      user: user,
      name: user.name,
      start_time: 1.day.from_now,
      course: "テストコース",
      status: "tentative"
    )
    
    begin
      # メール送信テスト
      ReservationMailer.confirmation(reservation).deliver_now
      puts "✅ メール送信テスト成功: #{user.email}"
    rescue => e
      puts "❌ メール送信テスト失敗: #{e.message}"
      puts "   設定を確認してください"
    end
  end
  
  desc "LINE通知のテスト送信"
  task test_line: :environment do
    puts "📱 LINE通知テスト開始"
    
    # LINE連携しているユーザーを取得
    user = User.where.not(line_user_id: nil).first
    if user.nil?
      puts "❌ LINE連携しているユーザーが見つかりません"
      next
    end
    
    # テスト用の予約を作成
    reservation = Reservation.new(
      user: user,
      name: user.name,
      start_time: 1.day.from_now,
      course: "テストコース",
      status: "tentative"
    )
    
    begin
      # LINE通知テスト
      LineBookingNotifier.new_booking_request(reservation)
      puts "✅ LINE通知テスト成功: #{user.name}"
    rescue => e
      puts "❌ LINE通知テスト失敗: #{e.message}"
      puts "   設定を確認してください"
    end
  end
  
  desc "全通知機能のテスト"
  task test_all: [:test_config, :test_email, :test_line] do
    puts "\n🎯 全通知機能テスト完了"
  end
end

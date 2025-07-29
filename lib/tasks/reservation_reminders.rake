# lib/tasks/reservation_reminders.rake

namespace :reservation do
  desc "Send LINE reminders for upcoming reservations"
  task send_reminders: :environment do
    puts "[#{Time.current}] 予約リマインダータスク開始"
    
    # 明日の予約を取得
    tomorrow = Date.current + 1.day
    upcoming_reservations = Reservation.active
      .includes(:user)
      .where(start_time: tomorrow.beginning_of_day..tomorrow.end_of_day)
      .where(reminder_sent_at: nil) # まだリマインダーを送信していない予約のみ
    
    puts "明日(#{tomorrow})の予約数: #{upcoming_reservations.count}件"
    
    upcoming_reservations.each do |reservation|
      user = reservation.user
      
      # ユーザーがLINE連携していない場合はスキップ
      next unless user&.line_user_id
      
      # 通知設定が無効の場合はスキップ
      next unless user.notification_preference&.enabled?
      
      begin
        # LINE通知送信
        LineBookingNotifier.send_reminder(reservation)
        puts "✅ リマインダー送信: #{user.name}様 - #{reservation.start_time.strftime('%H:%M')}"
        
        # 送信済みフラグを更新
        reservation.update_column(:reminder_sent_at, Time.current)
        
        # API制限対策で少し待機
        sleep(0.5)
        
      rescue => e
        puts "❌ リマインダー送信失敗: #{user.name}様 - #{e.message}"
        Rails.logger.error "予約リマインダー送信エラー: #{e.message}"
      end
    end
    
    puts "[#{Time.current}] 予約リマインダータスク完了"
  end
  
  desc "Send reservation confirmations for tentative bookings"
  task send_confirmations: :environment do
    puts "[#{Time.current}] 予約確認メール送信タスク開始"
    
    # 24時間以内に作成された仮予約で、まだ確認メールを送信していないもの
    tentative_reservations = Reservation.tentative
      .includes(:user)
      .where(created_at: 24.hours.ago..Time.current)
      .where(confirmation_sent_at: nil)
    
    puts "未確認の仮予約数: #{tentative_reservations.count}件"
    
    tentative_reservations.each do |reservation|
      user = reservation.user
      
      begin
        # メール送信（メールアドレスがある場合）
        if user.email.present?
          ReservationMailer.confirmation(reservation).deliver_now
          puts "✅ 確認メール送信: #{user.name}様 (#{user.email})"
        end
        
        # LINE通知送信（LINE連携している場合）
        if user.line_user_id.present?
          LineBookingNotifier.new_booking_request(reservation)
          puts "✅ LINE通知送信: #{user.name}様"
        end
        
        # 送信済みフラグを更新
        reservation.update_column(:confirmation_sent_at, Time.current)
        
        sleep(0.5)
        
      rescue => e
        puts "❌ 確認通知送信失敗: #{user.name}様 - #{e.message}"
        Rails.logger.error "予約確認通知送信エラー: #{e.message}"
      end
    end
    
    puts "[#{Time.current}] 予約確認メール送信タスク完了"
  end
  
  desc "Clean up old cancelled reservations"
  task cleanup_old_reservations: :environment do
    puts "[#{Time.current}] 古い予約データクリーンアップ開始"
    
    # 3ヶ月以上前のキャンセル済み予約を削除
    old_cancelled = Reservation.cancelled
      .where('cancelled_at < ?', 3.months.ago)
    
    count = old_cancelled.count
    old_cancelled.destroy_all
    
    puts "削除した古いキャンセル予約: #{count}件"
    
    # 6ヶ月以上前の完了予約を削除（必要に応じて）
    # old_completed = Reservation.completed
    #   .where('start_time < ?', 6.months.ago)
    # 
    # completed_count = old_completed.count
    # old_completed.destroy_all
    # 
    # puts "削除した古い完了予約: #{completed_count}件"
    
    puts "[#{Time.current}] 古い予約データクリーンアップ完了"
  end
end
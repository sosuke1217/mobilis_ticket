# lib/tasks/google_calendar_sync.rake
# Googleカレンダー自動同期タスク

namespace :google_calendar do
  desc "Sync reservations from Google Calendar"
  task sync_from_google: :environment do
    puts "[#{Time.current}] Googleカレンダー同期タスク開始"
    
    # 同期が有効になっているか確認
    unless ENV['GOOGLE_CALENDAR_SYNC_ENABLED'] == 'true'
      puts "⚠️ Googleカレンダー同期が無効になっています。環境変数 GOOGLE_CALENDAR_SYNC_ENABLED=true を設定してください。"
      next
    end
    
    begin
      sync_service = GoogleCalendarSync.new
      
      # 認証状態を確認
      unless sync_service.authorized?
        puts "⚠️ Googleカレンダーが認証されていません。管理画面から認証を完了してください。"
        next
      end
      
      # 今日から30日後までの予約を同期
      result = sync_service.sync_events_to_reservations(
        start_time: Time.current.beginning_of_day,
        end_time: 30.days.from_now.end_of_day
      )
      
      puts "✅ Googleカレンダー同期完了: #{result[:synced]}件処理（新規: #{result[:created]}件、更新: #{result[:updated]}件）"
      
    rescue => e
      puts "❌ Googleカレンダー同期エラー: #{e.message}"
      Rails.logger.error "Googleカレンダー同期エラー: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(10).join("\n")}"
    end
    
    puts "[#{Time.current}] Googleカレンダー同期タスク完了"
  end

  desc "Renew expired webhook channels"
  task renew_channels: :environment do
    puts "[#{Time.current}] Googleカレンダーチャンネル更新タスク開始"
    
    unless ENV['GOOGLE_CALENDAR_SYNC_ENABLED'] == 'true'
      puts "⚠️ Googleカレンダー同期が無効になっています。環境変数 GOOGLE_CALENDAR_SYNC_ENABLED=true を設定してください。"
      next
    end
    
    begin
      sync_service = GoogleCalendarSync.new
      
      # 認証状態を確認
      unless sync_service.authorized?
        puts "⚠️ Googleカレンダーが認証されていません。管理画面から認証を完了してください。"
        next
      end
      
      expired_channels = GoogleCalendarChannel.expired
      
      if expired_channels.empty?
        puts "✅ 期限切れのチャンネルはありません"
        next
      end
      
      expired_channels.each do |channel|
        puts "🔄 Renewing expired channel: #{channel.channel_id}"
        
        # 古いチャンネルを停止
        sync_service.stop_channel(channel.channel_id, channel.resource_id)
        
        # 新しいチャンネルを登録
        new_channel = sync_service.watch_calendar(channel.webhook_url)
        
        if new_channel
          channel.update!(
            channel_id: new_channel.id,
            resource_id: new_channel.resource_id,
            expiration: Time.at(new_channel.expiration / 1000)
          )
          puts "✅ Channel renewed: #{new_channel.id}, expiration: #{Time.at(new_channel.expiration / 1000)}"
        else
          puts "❌ Failed to renew channel: #{channel.channel_id}"
        end
      end
      
      puts "[#{Time.current}] Googleカレンダーチャンネル更新タスク完了"
    rescue => e
      puts "❌ Channel renewal error: #{e.message}"
      Rails.logger.error "Channel renewal error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(10).join("\n")}"
    end
  end
end


# Googleカレンダー Push Notifications（Webhook）実装ガイド

## 📋 概要

Google Calendar APIの**Push Notifications**機能を使用すると、Googleカレンダーに変更があったときにリアルタイムでWebhook通知を受け取ることができます。これにより、Heroku Schedulerのような定期実行ではなく、変更があったときだけ同期処理を実行できます。

## 🎯 メリット

1. **リアルタイム同期**: 変更があったときだけ即座に同期
2. **効率的**: ポーリング不要でAPI呼び出しを削減
3. **コスト削減**: dynoの使用時間を節約
4. **10分間隔の制限なし**: Heroku Schedulerの制限に依存しない

## ⚠️ デメリット・注意点

1. **Webhook URLが必要**: HTTPSでアクセス可能な公開URLが必要
2. **チャンネル管理**: チャンネルの有効期限（最大7日）を管理する必要がある
3. **実装が複雑**: チャンネルの更新処理が必要

## 🚀 実装方法

### 1. Webhookエンドポイントの作成

`app/controllers/admin/google_calendar_controller.rb`に以下を追加：

```ruby
def webhook
  # Googleからの通知を処理
  channel_id = request.headers['X-Goog-Channel-Id']
  resource_id = request.headers['X-Goog-Resource-Id']
  resource_state = request.headers['X-Goog-Resource-State']
  resource_uri = request.headers['X-Goog-Resource-URI']
  
  Rails.logger.info "🔔 Google Calendar webhook received: channel_id=#{channel_id}, state=#{resource_state}"
  
  # 初回の通知（sync）は無視
  if resource_state == 'sync'
    head :ok
    return
  end
  
  # 変更通知の場合、同期を実行
  if resource_state == 'exists' || resource_state == 'not_exists'
    begin
      sync_service = GoogleCalendarSync.new
      result = sync_service.sync_events_to_reservations(
        start_time: Time.current.beginning_of_day,
        end_time: 30.days.from_now.end_of_day
      )
      Rails.logger.info "✅ Webhook sync completed: #{result[:synced]} events processed"
    rescue => e
      Rails.logger.error "❌ Webhook sync error: #{e.message}"
    end
  end
  
  head :ok
end
```

### 2. ルートの追加

`config/routes.rb`に追加：

```ruby
namespace :admin do
  resources :google_calendar, only: [:index] do
    collection do
      # ... 既存のルート ...
      post 'webhook'  # Webhookエンドポイント
    end
  end
end
```

### 3. チャンネル登録機能の追加

`app/services/google_calendar_sync.rb`に以下を追加：

```ruby
# チャンネルを登録（Webhookを開始）
def watch_calendar(webhook_url, channel_id = SecureRandom.uuid)
  return unless authorized?
  
  channel = Google::Apis::CalendarV3::Channel.new(
    id: channel_id,
    type: 'web_hook',
    address: webhook_url,
    expiration: (Time.current + 7.days).to_i * 1000  # 7日間有効
  )
  
  result = @service.watch_event('primary', channel)
  Rails.logger.info "✅ Channel registered: #{result.id}, expiration: #{Time.at(result.expiration / 1000)}"
  
  # チャンネル情報をデータベースに保存
  GoogleCalendarChannel.find_or_create_by(channel_id: channel_id) do |c|
    c.resource_id = result.resource_id
    c.expiration = Time.at(result.expiration / 1000)
    c.webhook_url = webhook_url
  end
  
  result
rescue => e
  Rails.logger.error "❌ Failed to register channel: #{e.message}"
  nil
end

# チャンネルを停止
def stop_channel(channel_id, resource_id)
  return unless authorized?
  
  channel = Google::Apis::CalendarV3::Channel.new(
    id: channel_id,
    resource_id: resource_id
  )
  
  @service.stop_channel(channel)
  Rails.logger.info "✅ Channel stopped: #{channel_id}"
rescue => e
  Rails.logger.error "❌ Failed to stop channel: #{e.message}"
end
```

### 4. チャンネル管理用のモデル作成

マイグレーション：

```ruby
class CreateGoogleCalendarChannels < ActiveRecord::Migration[7.2]
  def change
    create_table :google_calendar_channels do |t|
      t.string :channel_id, null: false, index: { unique: true }
      t.string :resource_id, null: false
      t.datetime :expiration, null: false
      t.string :webhook_url, null: false
      t.timestamps
    end
  end
end
```

モデル：

```ruby
class GoogleCalendarChannel < ApplicationRecord
  validates :channel_id, presence: true, uniqueness: true
  validates :resource_id, presence: true
  validates :expiration, presence: true
  validates :webhook_url, presence: true
  
  scope :active, -> { where('expiration > ?', Time.current) }
  scope :expired, -> { where('expiration <= ?', Time.current) }
end
```

### 5. チャンネル更新のRakeタスク

`lib/tasks/google_calendar_sync.rake`に追加：

```ruby
namespace :google_calendar do
  desc "Renew expired webhook channels"
  task renew_channels: :environment do
    puts "[#{Time.current}] Googleカレンダーチャンネル更新タスク開始"
    
    unless ENV['GOOGLE_CALENDAR_SYNC_ENABLED'] == 'true'
      puts "⚠️ Googleカレンダー同期が無効になっています"
      next
    end
    
    begin
      sync_service = GoogleCalendarSync.new
      expired_channels = GoogleCalendarChannel.expired
      
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
          puts "✅ Channel renewed: #{new_channel.id}"
        end
      end
      
      puts "[#{Time.current}] Googleカレンダーチャンネル更新タスク完了"
    rescue => e
      puts "❌ Channel renewal error: #{e.message}"
      Rails.logger.error "Channel renewal error: #{e.message}"
    end
  end
end
```

## 📝 セットアップ手順

### 1. マイグレーション実行

```bash
rails generate migration CreateGoogleCalendarChannels
# 上記のマイグレーションファイルを編集
rails db:migrate
```

### 2. Webhook URLの設定

Herokuの場合、以下のようなURLになります：

```
https://your-app-name.herokuapp.com/admin/google_calendar/webhook
```

### 3. チャンネル登録

管理画面から「チャンネルを登録」ボタンを追加し、以下のように実行：

```ruby
sync_service = GoogleCalendarSync.new
webhook_url = "https://your-app-name.herokuapp.com/admin/google_calendar/webhook"
sync_service.watch_calendar(webhook_url)
```

### 4. チャンネル更新のスケジュール

Heroku Schedulerで1日1回、チャンネル更新タスクを実行：

```
Schedule: Daily at 00:00 UTC
Run Command: rake google_calendar:renew_channels
```

## 🔄 運用フロー

1. **初回登録**: 管理画面からチャンネルを登録
2. **自動更新**: Heroku Schedulerで1日1回チャンネルを更新（7日間有効期限のため）
3. **リアルタイム同期**: Googleカレンダーに変更があると、即座にWebhookが呼ばれ同期が実行される

## ⚠️ 注意事項

- **チャンネル有効期限**: 最大7日間。定期的に更新が必要
- **Webhook URL**: HTTPSでアクセス可能である必要がある
- **リトライ**: Googleは失敗した場合、指数バックオフでリトライする
- **セキュリティ**: Webhookエンドポイントに認証を追加することを推奨

## 🆚 Heroku Schedulerとの比較

| 項目 | Heroku Scheduler | Push Notifications |
|------|----------------|-------------------|
| 同期タイミング | 定期実行（10分〜） | リアルタイム |
| 実装の複雑さ | 簡単 | やや複雑 |
| コスト | dyno使用時間 | dyno使用時間（少ない） |
| チャンネル管理 | 不要 | 必要（7日ごとに更新） |
| 推奨用途 | 定期バッチ処理 | リアルタイム同期 |

## 💡 推奨アプローチ

**ハイブリッド方式**を推奨します：

1. **Push Notifications**: リアルタイム同期用（メイン）
2. **Heroku Scheduler**: チャンネル更新用（1日1回）とフォールバック用（1時間ごと）

これにより、リアルタイム同期のメリットを享受しつつ、チャンネル期限切れやWebhook失敗時のバックアップも確保できます。


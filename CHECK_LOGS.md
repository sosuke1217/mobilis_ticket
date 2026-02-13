# ログの確認方法

## Herokuのログを確認する方法

### 1. リアルタイムでログを確認（推奨）

ターミナルで以下のコマンドを実行すると、リアルタイムでログが表示されます：

```bash
heroku logs --tail
```

このコマンドを実行した状態で予約を作成すると、Googleカレンダー同期に関するログが表示されます。

### 2. 最新のログを確認

最新のログ（デフォルトで100行）を確認する場合：

```bash
heroku logs
```

### 3. より多くのログを確認

最新の500行のログを確認する場合：

```bash
heroku logs -n 500
```

### 4. 特定のキーワードでログを検索

Googleカレンダー関連のログだけを確認する場合：

```bash
heroku logs --tail | grep -i "google\|calendar\|sync"
```

または、エラーログだけを確認する場合：

```bash
heroku logs --tail | grep -i "error\|failed\|❌"
```

## ログで確認すべき内容

予約を作成した際に、以下のようなログが表示されるはずです：

### 正常な場合：
```
🔄 sync_to_google_calendar called for reservation 123
🔄 should_sync_to_google_calendar? = true
🔄 ENV['GOOGLE_CALENDAR_SYNC_ENABLED'] = true
🔄 Creating GoogleCalendarSync service...
🔄 GoogleCalendarSync initializing...
🔄 Credentials file exists: true
🔄 Token file exists: true
🔄 Authorization result: SUCCESS
🔄 GoogleCalendarSync service created, authorized? = true
🔄 Creating new event...
🔄 Event built: 予約名 from 2026-02-13 10:00:00 to 2026-02-13 11:00:00
✅ Google Calendar event created: abc123xyz for reservation 123
✅ Successfully synced reservation 123 to Google Calendar
```

### エラーの場合：
```
🔄 sync_to_google_calendar called for reservation 123
🔄 should_sync_to_google_calendar? = false
🔄 ENV['GOOGLE_CALENDAR_SYNC_ENABLED'] = nil
```

または

```
🔄 Authorization result: FAILED
❌ Not authorized to create Google Calendar event
❌ Failed to sync reservation 123 to Google Calendar: ...
```

## トラブルシューティング

### 環境変数が設定されていない場合

```bash
heroku config:set GOOGLE_CALENDAR_SYNC_ENABLED=true
```

### 認証トークンが存在しない場合

管理画面の「Googleカレンダー連携設定」ページから再度認証を行ってください。

### ログが表示されない場合

1. 予約を作成した直後にログを確認してください
2. `heroku logs --tail` を実行してから予約を作成してください
3. アプリケーションを再起動してください：
   ```bash
   heroku restart
   ```


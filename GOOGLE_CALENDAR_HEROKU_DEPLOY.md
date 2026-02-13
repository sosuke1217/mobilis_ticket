# Googleカレンダー連携のHerokuデプロイ手順

## 📋 デプロイ前の確認事項

### 1. ローカルでの動作確認
- [ ] データベースマイグレーションが完了している
- [ ] `.env`ファイルに`GOOGLE_CALENDAR_SYNC_ENABLED=true`が設定されている
- [ ] `config/google_calendar_credentials.json`が配置されている
- [ ] ローカルで認証が成功している

## 🚀 Herokuデプロイ手順

### 1. コードのコミットとプッシュ

```bash
# 変更をコミット
git add .
git commit -m "Googleカレンダー連携機能を追加"

# Herokuにプッシュ
git push heroku main
```

### 2. 環境変数の設定

```bash
# Googleカレンダー同期を有効化
heroku config:set GOOGLE_CALENDAR_SYNC_ENABLED=true
```

### 3. データベースマイグレーション

```bash
# マイグレーションの実行
heroku run rails db:migrate
```

### 4. 認証情報の環境変数設定（推奨）

Herokuでは、環境変数から認証情報ファイルを動的に生成します。これにより、デプロイのたびに再配置する必要がなくなります。

```bash
# 認証情報を環境変数として設定
heroku config:set GOOGLE_CALENDAR_CLIENT_ID="1082079540400-ta3lg7vq2jeloc6gpl9jud02n8bn94oa.apps.googleusercontent.com"
heroku config:set GOOGLE_CALENDAR_CLIENT_SECRET="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"
heroku config:set GOOGLE_CALENDAR_PROJECT_ID="mobilis-ticket"
```

**注意**: アプリケーション起動時に、`config/initializers/google_calendar_credentials.rb`が環境変数から認証情報ファイルを自動生成します。

#### 方法2: ファイルシステムに直接配置（非推奨）

認証情報を環境変数として設定し、アプリケーション起動時にファイルを生成する方法：

```bash
# 認証情報を環境変数として設定
heroku config:set GOOGLE_CALENDAR_CLIENT_ID="YOUR_CLIENT_ID"
heroku config:set GOOGLE_CALENDAR_CLIENT_SECRET="YOUR_CLIENT_SECRET"
heroku config:set GOOGLE_CALENDAR_PROJECT_ID="YOUR_PROJECT_ID"
```

その後、`config/initializers/google_calendar.rb`を作成して、環境変数から認証情報ファイルを生成します。

### 5. Gemのインストール確認

```bash
# Gemfileに追加されたgemがインストールされているか確認
heroku run bundle install
```

### 6. アプリケーションの再起動

```bash
# アプリケーションを再起動
heroku restart
```

## 🔐 認証の実行

### 1. 管理画面にアクセス

```
https://your-app-name.herokuapp.com/admin/google_calendar
```

### 2. 認証を実行

1. 「認証を開始」ボタンをクリック
2. Googleアカウントでログイン
3. アクセス権限を許可
4. 認証が完了すると、`config/google_calendar_token.yaml`が作成されます

**注意**: Herokuのファイルシステムは一時的なので、認証トークンも定期的に再認証が必要になる場合があります。

## ⚠️ 重要な注意事項

### ファイルシステムの制限

Herokuのファイルシステム（`/app`）は一時的です：
- デプロイのたびにクリーンな状態になります
- ファイルへの書き込みは可能ですが、再起動やデプロイで失われる可能性があります
- 認証トークン（`google_calendar_token.yaml`）も同様です

### 推奨される解決策

1. **認証情報ファイル**: 環境変数から動的に生成する
2. **認証トークン**: 定期的に再認証するか、データベースに保存する（実装が必要）

## 🔄 継続的な運用

### 自動同期の設定（Heroku Scheduler）

Googleカレンダーから予約を自動的に同期するには、Heroku Schedulerアドオンを使用します。

#### 1. Heroku Schedulerアドオンの追加

```bash
# Heroku Schedulerアドオンを追加（無料プランで利用可能）
heroku addons:create scheduler:standard
```

#### 2. Schedulerダッシュボードで設定

```bash
# Schedulerダッシュボードを開く
heroku addons:open scheduler
```

または、Heroku Dashboardから：
1. アプリケーションを選択
2. 「Resources」タブを開く
3. 「Heroku Scheduler」をクリック
4. 「Create job」をクリック

#### 3. ジョブの設定

以下の設定でジョブを作成：

- **Schedule**: `Every 10 minutes`（10分ごと）または `Every 1 hour`（1時間ごと）
- **Run Command**: `rake google_calendar:sync_from_google`

**推奨設定**:
- **頻繁な同期が必要な場合**: `Every 10 minutes`
- **通常の運用**: `Every 1 hour`

#### 4. 手動実行でのテスト

設定前に、手動で実行して動作を確認：

```bash
# 手動で同期タスクを実行
heroku run rake google_calendar:sync_from_google
```

### 定期的な再認証

認証トークンが期限切れになった場合：

1. 管理画面の「Googleカレンダー連携設定」にアクセス
2. 「認証を開始」ボタンから再認証を実行

### ログの確認

```bash
# アプリケーションログを確認
heroku logs --tail

# Googleカレンダー関連のエラーを確認
heroku logs --tail | grep -i "google\|calendar"

# スケジューラーの実行ログを確認
heroku logs --tail | grep -i "scheduler\|google_calendar"
```

## 🐛 トラブルシューティング

### 認証情報ファイルが見つからない

```bash
# Herokuのファイルシステムを確認
heroku run ls -la config/
```

### 環境変数が設定されていない

```bash
# 環境変数を確認
heroku config | grep GOOGLE
```

### マイグレーションエラー

```bash
# マイグレーションの状態を確認
heroku run rails db:migrate:status
```


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


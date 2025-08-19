# 🚀 Herokuでのデプロイ手順書

## 📋 事前準備

### ✅ 必要なツール
- [x] Heroku CLI
- [x] Git
- [x] Ruby 3.3.x
- [x] Rails 7.2.2.1

### 🔑 必要な認証情報
- [x] Gmailアプリパスワード
- [x] LINE Bot Channel Secret
- [x] LINE Bot Channel Token

## 🔧 Herokuアプリの準備

### 1. Heroku CLIのインストールとログイン
```bash
# Heroku CLIのインストール（macOS）
brew tap heroku/brew && brew install heroku

# ログイン
heroku login
```

### 2. 新しいHerokuアプリの作成
```bash
# アプリの作成
heroku create mobilis-ticket-app

# または既存のアプリを使用
heroku git:remote -a your-existing-app-name
```

### 3. 必要なアドオンの追加
```bash
# PostgreSQLデータベースの追加
heroku addons:create heroku-postgresql:mini

# Redisの追加（必要に応じて）
# heroku addons:create heroku-redis:mini

# ログ監視の追加
heroku addons:create papertrail:choklad
```

## 📦 アプリケーションのデプロイ

### 1. コードの準備
```bash
# 現在のディレクトリで
git add .
git commit -m "Herokuデプロイ用の設定追加"

# Herokuリモートの追加
heroku git:remote -a your-app-name
```

### 2. 環境変数の設定
```bash
# Gmail設定
heroku config:set GMAIL_USERNAME="mobilis.stretch@gmail.com"
heroku config:set GMAIL_APP_PASSWORD="xtjg clst hbpw rsho"

# LINE Bot設定
heroku config:set LINE_CHANNEL_SECRET="360b1b477e3025114f7ecde7f4f05f79"
heroku config:set LINE_CHANNEL_TOKEN="hojBYvKt8rfBN4+/gRMdMyzofkMCb7HlJhaOFufi/hRGPPG/AGzeJZde3CLoxLoNCaei7wa92TO4xIt+kyviaS6SUS5Q9Hrj+WSJFN8ySGxFFIRICA5hU0Ha2tONO6YcLrXgbJOqmD6Y1SwbmGKEhgdB04t89/1O/w1cDnyilFU="

# 管理者設定
heroku config:set ADMIN_EMAIL="mobilis.stretch@gmail.com"
heroku config:set MAIL_FROM="mobilis.stretch@gmail.com"

# アプリケーション設定
heroku config:set APP_HOST="https://your-app-name.herokuapp.com"
heroku config:set RAILS_ENV="production"
```

### 3. デプロイの実行
```bash
# Herokuにプッシュ
git push heroku main

# データベースのセットアップ
heroku run rails db:create
heroku run rails db:migrate
heroku run rails db:seed

# アセットのプリコンパイル
heroku run rails assets:precompile
```

## 🔍 デプロイ後の確認

### 1. アプリケーションの起動確認
```bash
# アプリの起動確認
heroku open

# ログの確認
heroku logs --tail
```

### 2. 基本機能の動作確認
- [ ] アプリケーションが正常に起動する
- [ ] データベースにアクセスできる
- [ ] メール送信が正常に動作する
- [ ] LINE Botが正常に応答する

### 3. LINE Bot設定の更新
```bash
# LINE Developersコンソールで以下を更新
- Webhook URL: https://your-app-name.herokuapp.com/linebot/callback
- リッチメニューの設定
```

## 🚨 よくある問題と対処法

### 1. データベース接続エラー
```bash
# データベースの状態確認
heroku pg:info

# データベースのリセット（注意：データが消えます）
heroku pg:reset DATABASE_URL
```

### 2. メール送信エラー
```bash
# 環境変数の確認
heroku config:get GMAIL_USERNAME
heroku config:get GMAIL_APP_PASSWORD

# ログの確認
heroku logs --tail | grep "mail"
```

### 3. LINE Bot応答エラー
```bash
# 環境変数の確認
heroku config:get LINE_CHANNEL_SECRET
heroku config:get LINE_CHANNEL_TOKEN

# Webhook URLの確認
curl -X POST https://your-app-name.herokuapp.com/linebot/callback
```

## 🔄 更新・再デプロイ

### 1. コードの更新
```bash
# コードを変更後
git add .
git commit -m "機能更新"
git push heroku main
```

### 2. 環境変数の更新
```bash
# 環境変数を変更後
heroku config:set VARIABLE_NAME="new_value"
```

### 3. データベースの更新
```bash
# マイグレーションの実行
heroku run rails db:migrate
```

## 📊 監視・メンテナンス

### 1. ログの監視
```bash
# リアルタイムログ
heroku logs --tail

# 特定の時間のログ
heroku logs --since "1 hour ago"
```

### 2. パフォーマンスの監視
```bash
# アプリの状態確認
heroku ps

# データベースの状態確認
heroku pg:info
```

### 3. バックアップ
```bash
# データベースのバックアップ
heroku pg:backups:capture

# バックアップのダウンロード
heroku pg:backups:download
```

## 🎯 次のステップ

### 1. カスタムドメインの設定
```bash
# カスタムドメインの追加
heroku domains:add www.yourdomain.com

# SSL証明書の自動更新
heroku certs:auto:enable
```

### 2. スケーリング
```bash
# 動的スケーリングの有効化
heroku ps:scale web=1
```

### 3. 監視ツールの追加
```bash
# New Relicの追加
heroku addons:create newrelic:wayne
```

## 📞 サポート情報

### 緊急時の連絡先
- Herokuサポート: https://help.heroku.com/
- LINE Botサポート: https://developers.line.biz/ja/docs/

### ログファイルの場所
- アプリケーションログ: `heroku logs --tail`
- データベースログ: `heroku pg:logs`
- アドオンログ: `heroku addons:open papertrail`

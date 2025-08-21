# Heroku本番環境移行手順書

## 🚀 Heroku本番環境への移行手順

### 1. Heroku CLIのインストールとログイン

```bash
# Heroku CLIのインストール（macOS）
brew install heroku/brew/heroku

# ログイン
heroku login
```

### 2. Herokuアプリの作成

```bash
# アプリの作成
heroku create mobilis-stretch-bot

# リモートの確認
git remote -v
```

### 3. Heroku Postgresアドオンの追加

```bash
# PostgreSQLアドオンの追加
heroku addons:create heroku-postgresql:mini

# データベース情報の確認
heroku config | grep DATABASE_URL
```

### 4. Heroku Redisアドオンの追加（必要に応じて）

```bash
# Redisアドオンの追加
heroku addons:create heroku-redis:mini

# Redis情報の確認
heroku config | grep REDIS_URL
```

### 5. 環境変数の設定

```bash
# LINE Bot設定
heroku config:set LINE_CHANNEL_SECRET="360b1b477e3025114f7ecde7f4f05f79"
heroku config:set LINE_CHANNEL_TOKEN="hojBYvKt8rfBN4+/gRMdMyzofkMCb7HlJhaOFufi/hRGPPG/AGzeJZde3CLoxLoNCaei7wa92TO4xIt+kyviaS6SUS5Q9Hrj+WSJFN8ySGxFFIRICA5hU0Ha2tONO6YcLrXgbJOqmD6Y1SwbmGKEhgdB04t89/1O/w1cDnyilFU="

# Gmail設定
heroku config:set GMAIL_USERNAME="mobilis.stretch@gmail.com"
heroku config:set GMAIL_APP_PASSWORD="xtjg clst hbpw rsho"

# 管理者設定
heroku config:set ADMIN_EMAIL="mobilis.stretch@gmail.com"
heroku config:set MAIL_FROM="mobilis.stretch@gmail.com"

# アプリケーション設定
heroku config:set APP_HOST="https://your-heroku-app-name.herokuapp.com"
heroku config:set RAILS_ENV="production"

# セキュリティ設定
heroku config:set RAILS_MASTER_KEY="$(cat config/master.key)"
```

### 6. データベースの準備

```bash
# データベースのマイグレーション
heroku run rails db:migrate

# シードデータ投入（必要に応じて）
heroku run rails db:seed
```

### 7. アセットのプリコンパイル

```bash
# アセットのプリコンパイル
heroku run rails assets:precompile

# アセットのクリーンアップ
heroku run rails assets:clean
```

### 8. LINEリッチメニューの設定

```bash
# リッチメニューの設定
heroku run ruby lib/line_rich_menu_setup.rb
```

### 9. アプリケーションのデプロイ

```bash
# コードのプッシュ
git add .
git commit -m "Heroku本番環境用設定"
git push heroku main

# アプリケーションの起動確認
heroku open
```

### 10. 本番環境での動作確認

以下の機能が正常に動作することを確認：

- ✅ LINEボットの応答
- ✅ 予約システム
- ✅ チケット管理
- ✅ 通知機能
- ✅ 管理者ダッシュボード

### 11. ログの監視

```bash
# リアルタイムログの確認
heroku logs --tail

# 特定の時間のログ
heroku logs --since 1h
```

### 12. スケーリング設定

```bash
# Web dynoのスケーリング
heroku ps:scale web=1

# Worker dynoの追加（必要に応じて）
heroku ps:scale worker=1
```

## 🔧 トラブルシューティング

### よくある問題と解決方法

1. **データベース接続エラー**
   ```bash
   # データベースの状態確認
   heroku pg:info
   
   # データベースのリセット（注意：データが消えます）
   heroku pg:reset DATABASE_URL
   ```

2. **LINE Bot API エラー**
   - 環境変数`LINE_CHANNEL_SECRET`と`LINE_CHANNEL_TOKEN`の確認
   - LINE Developer Consoleでの設定確認
   - Webhook URLの設定確認

3. **アセット読み込みエラー**
   ```bash
   # アセットの再プリコンパイル
   heroku run rails assets:precompile
   heroku run rails assets:clean
   ```

4. **メモリ不足エラー**
   ```bash
   # より大きなdynoにアップグレード
   heroku ps:type standard-1x
   ```

## 📊 Herokuアドオン管理

### 現在のアドオン確認
```bash
heroku addons
```

### アドオンの削除
```bash
heroku addons:destroy heroku-postgresql:mini
```

### アドオンのアップグレード
```bash
heroku addons:upgrade heroku-postgresql:mini heroku-postgresql:basic
```

## 🎯 次のステップ

本番環境での動作確認後：

1. **カスタムドメインの設定**
   ```bash
   heroku domains:add mobilis-stretch.com
   ```

2. **SSL証明書の自動更新**（Herokuで自動管理）

3. **監視・アラートの設定**
   ```bash
   heroku addons:create papertrail:choklad
   ```

4. **バックアップの設定**
   ```bash
   heroku pg:backups schedule DATABASE_URL --at '02:00 UTC'
   ```

5. **パフォーマンス監視**
   ```bash
   heroku addons:create newrelic:wayne
   ```

## 💰 コスト管理

### 現在の使用量確認
```bash
heroku addons:plans
```

### 月額料金の確認
```bash
heroku billing:info
```

## 📞 サポート

問題が発生した場合は、以下を確認してください：

1. Herokuログ（`heroku logs --tail`）
2. 環境変数の設定状況（`heroku config`）
3. データベースの状態（`heroku pg:info`）
4. LINE Bot APIの設定状況

## 🚨 重要な注意事項

- **環境変数**: 機密情報は必ず`heroku config:set`で設定
- **データベース**: 本番環境でのデータ操作は慎重に行う
- **ログ**: 機密情報がログに出力されていないか確認
- **バックアップ**: 定期的なバックアップを設定

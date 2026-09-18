# Herokuデプロイ手順書

## 🚀 クイックスタート

### 1. Heroku CLIのインストール

```bash
# macOS
brew install heroku/brew/heroku

# Windows
# https://devcenter.heroku.com/articles/heroku-cli からダウンロード

# Linux
curl https://cli-assets.heroku.com/install.sh | sh
```

### 2. ログイン

```bash
heroku login
```

### 3. アプリの作成

```bash
# アプリの作成
heroku create mobilis-stretch-bot

# リモートの確認
git remote -v
```

## 📦 アドオンの追加

### PostgreSQLデータベース

```bash
# 無料プラン（開発用）
heroku addons:create heroku-postgresql:mini

# 有料プラン（本番用）
heroku addons:create heroku-postgresql:basic
```

### Redis（必要に応じて）

```bash
# 無料プラン
heroku addons:create heroku-redis:mini

# 有料プラン
heroku addons:create heroku-redis:basic
```

## 🔧 環境変数の設定

### LINE Bot設定

```bash
heroku config:set LINE_CHANNEL_SECRET="<LINE_CHANNEL_SECRET>" --app <HEROKU_APP_NAME>
heroku config:set LINE_CHANNEL_TOKEN="<LINE_CHANNEL_TOKEN>" --app <HEROKU_APP_NAME>
```

### Gmail設定

```bash
heroku config:set GMAIL_USERNAME="<GMAIL_USERNAME>" --app <HEROKU_APP_NAME>
heroku config:set GMAIL_APP_PASSWORD="<GMAIL_APP_PASSWORD>" --app <HEROKU_APP_NAME>
```

### 管理者設定

```bash
heroku config:set ADMIN_EMAIL="mobilis.stretch@gmail.com"
heroku config:set MAIL_FROM="mobilis.stretch@gmail.com"
```

### アプリケーション設定

```bash
# アプリ名を実際の名前に変更
heroku config:set APP_HOST="https://mobilis-stretch-bot.herokuapp.com"
heroku config:set RAILS_ENV="production"
```

### セキュリティ設定

```bash
# master.keyファイルから設定
heroku config:set RAILS_MASTER_KEY="$(cat config/master.key)"
```

## 🗄️ データベースの準備

### マイグレーション

```bash
# データベースのマイグレーション
heroku run rails db:migrate

# シードデータ投入（必要に応じて）
heroku run rails db:seed
```

### データベースの確認

```bash
# データベース情報
heroku pg:info

# データベース接続
heroku pg:psql
```

## 🎨 アセットの準備

### プリコンパイル

```bash
# アセットのプリコンパイル
heroku run rails assets:precompile

# アセットのクリーンアップ
heroku run rails assets:clean
```

## 📱 LINEリッチメニューの設定

```bash
# リッチメニューの設定
heroku run ruby lib/line_rich_menu_setup.rb
```

## 🚀 デプロイ

### コードのプッシュ

```bash
# 変更をコミット
git add .
git commit -m "Heroku本番環境用設定"

# Herokuにプッシュ
git push heroku main
```

### アプリケーションの起動

```bash
# アプリケーションの起動確認
heroku open

# ログの確認
heroku logs --tail
```

## 📊 監視と管理

### ログの確認

```bash
# リアルタイムログ
heroku logs --tail

# 特定の時間のログ
heroku logs --since 1h

# エラーログのみ
heroku logs --tail --source app --level error
```

### アプリケーションの状態

```bash
# dynoの状態
heroku ps

# アプリケーションの情報
heroku info
```

### スケーリング

```bash
# Web dynoのスケーリング
heroku ps:scale web=1

# Worker dynoの追加（必要に応じて）
heroku ps:scale worker=1
```

## 🔍 トラブルシューティング

### よくある問題

1. **H10 - App Crashed**
   ```bash
   # ログの確認
   heroku logs --tail
   
   # アプリケーションの再起動
   heroku restart
   ```

2. **H14 - No Web Processes Running**
   ```bash
   # Web dynoの起動
   heroku ps:scale web=1
   ```

3. **R10 - Boot Timeout**
   ```bash
   # アプリケーションの起動時間を確認
   heroku logs --tail
   ```

4. **R15 - Memory Quota Exceeded**
   ```bash
   # より大きなdynoにアップグレード
   heroku ps:type standard-1x
   ```

## 💰 コスト管理

### 料金プラン

- **Free**: 開発・テスト用（非推奨）
- **Basic**: $7/月 - 本番環境推奨
- **Standard**: $25/月 - 高負荷環境
- **Performance**: $250/月 - エンタープライズ

### アドオン料金

- **PostgreSQL Mini**: $5/月
- **PostgreSQL Basic**: $9/月
- **Redis Mini**: $15/月

### コスト削減のヒント

1. 不要なアドオンの削除
2. 適切なdynoサイズの選択
3. 定期的な使用量の確認

## 🎯 次のステップ

### カスタムドメイン

```bash
# カスタムドメインの追加
heroku domains:add mobilis-stretch.com

# DNSレコードの設定
# CNAME: mobilis-stretch.com → your-app.herokuapp.com
```

### SSL証明書

Herokuで自動管理されます。

### 監視・アラート

```bash
# ログ監視
heroku addons:create papertrail:choklad

# パフォーマンス監視
heroku addons:create newrelic:wayne
```

### バックアップ

```bash
# 手動バックアップ
heroku pg:backups capture

# 自動バックアップ（毎日2:00 UTC）
heroku pg:backups schedule DATABASE_URL --at '02:00 UTC'
```

## 📞 サポート

### Herokuサポート

- [Heroku Dev Center](https://devcenter.heroku.com/)
- [Heroku Status](https://status.heroku.com/)
- [Heroku Support](https://help.heroku.com/)

### アプリケーション固有の問題

1. ログの確認（`heroku logs --tail`）
2. 環境変数の確認（`heroku config`）
3. データベースの状態確認（`heroku pg:info`）
4. LINE Bot APIの設定確認

## 🚨 重要な注意事項

- **環境変数**: 機密情報は必ず`heroku config:set`で設定
- **データベース**: 本番環境でのデータ操作は慎重に行う
- **ログ**: 機密情報がログに出力されていないか確認
- **バックアップ**: 定期的なバックアップを設定
- **コスト**: 無料プランは本番環境には適していません

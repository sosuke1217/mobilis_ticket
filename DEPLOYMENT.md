# 🚀 本番環境への移行手順書

## 📋 移行前の確認事項

### ✅ 実装済み機能
- [x] 予約システム（作成・編集・削除・キャンセル）
- [x] LINE通知（予約・リマインダー・キャンセル）
- [x] メール通知（確認・リマインダー・キャンセル）
- [x] 多言語対応（日本語・英語）
- [x] LINEリッチメニュー（6つのメニュー項目）
- [x] Googleレビュー機能
- [x] 最新情報機能

### ⚠️ 設定が必要な項目
- [ ] 本番ドメインの設定
- [ ] LINE Webhook URLの更新
- [ ] GoogleレビューURLの更新
- [ ] データベースの本番環境対応
- [ ] SSL証明書の設定

## 🔧 本番環境の準備

### 1. サーバー環境の準備
```bash
# 必要なソフトウェア
- Ruby 3.3.x
- Rails 7.2.2.1
- SQLite3 または PostgreSQL
- Nginx または Apache
- SSL証明書
```

### 2. 環境変数の設定
```bash
# 本番環境で設定する環境変数
export GMAIL_USERNAME="mobilis.stretch@gmail.com"
export GMAIL_APP_PASSWORD="xtjg clst hbpw rsho"
export LINE_CHANNEL_SECRET="360b1b477e3025114f7ecde7f4f05f79"
export LINE_CHANNEL_TOKEN="hojBYvKt8rfBN4+/gRMdMyzofkMCb7HlJhaOFufi/hRGPPG/AGzeJZde3CLoxLoNCaei7wa92TO4xIt+kyviaS6SUS5Q9Hrj+WSJFN8ySGxFFIRICA5hU0Ha2tONO6YcrXgbJOqmD6Y1SwbmGKEhgdB04t89/1O/w1cDnyilFU="
export ADMIN_EMAIL="mobilis.stretch@gmail.com"
export MAIL_FROM="mobilis.stretch@gmail.com"
export APP_HOST="https://your-production-domain.com"
export RAILS_ENV="production"
export SECRET_KEY_BASE="$(rails secret)"
```

## 📦 アプリケーションのデプロイ

### 1. コードのアップロード
```bash
# Gitリポジトリからクローン
git clone <your-repository-url>
cd mobilis_ticket

# 依存関係のインストール
bundle install --without development test

# データベースのセットアップ
rails db:create
rails db:migrate
rails db:seed

# アセットのプリコンパイル
rails assets:precompile
```

### 2. 設定ファイルの更新
```bash
# 本番環境用の設定ファイルをコピー
cp config/application.yml.production config/application.yml

# 本番ドメインに更新
sed -i 's/your-production-domain.com/actual-domain.com/g' config/application.yml
```

### 3. LINE Botの設定更新
```bash
# LINE Developersコンソールで以下を更新
- Webhook URL: https://your-domain.com/linebot/callback
- リッチメニューの設定
```

### 4. アプリケーションの起動
```bash
# 本番環境での起動
rails server -e production -p 3000

# または、systemdサービスとして設定
sudo systemctl enable mobilis-ticket
sudo systemctl start mobilis-ticket
```

## 🔍 移行後の確認事項

### 1. 基本動作確認
- [ ] アプリケーションが正常に起動する
- [ ] データベースにアクセスできる
- [ ] メール送信が正常に動作する
- [ ] LINE Botが正常に応答する

### 2. 機能テスト
- [ ] 予約作成・編集・削除
- [ ] LINE通知の送信
- [ ] メール通知の送信
- [ ] リッチメニューの動作
- [ ] 最新情報の表示

### 3. パフォーマンス確認
- [ ] レスポンス時間
- [ ] メモリ使用量
- [ ] データベースのパフォーマンス
- [ ] ログの出力状況

## 🚨 トラブルシューティング

### よくある問題と対処法

#### 1. メール送信エラー
```bash
# ログの確認
tail -f log/production.log

# Gmail設定の確認
rails runner "puts ActionMailer::Base.smtp_settings"
```

#### 2. LINE Bot応答エラー
```bash
# LINE Botのログ確認
tail -f log/production.log | grep "LINE"

# Webhook URLの確認
curl -X POST https://your-domain.com/linebot/callback
```

#### 3. データベース接続エラー
```bash
# データベース接続テスト
rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1')"
```

## 📞 サポート情報

### 緊急時の連絡先
- 開発者: [連絡先情報]
- LINE Bot管理者: [連絡先情報]
- サーバー管理者: [連絡先情報]

### ログファイルの場所
- アプリケーションログ: `log/production.log`
- システムログ: `/var/log/syslog`
- Nginxログ: `/var/log/nginx/`

## 🔄 定期メンテナンス

### 毎日の確認事項
- [ ] ログファイルの確認
- [ ] データベースのバックアップ
- [ ] 通知機能の動作確認

### 毎週の確認事項
- [ ] パフォーマンスの確認
- [ ] セキュリティアップデートの確認
- [ ] 最新情報の更新

### 毎月の確認事項
- [ ] システム全体の動作確認
- [ ] バックアップの復元テスト
- [ ] セキュリティ監査

# Herokuデプロイ チェックリスト

## 🚀 デプロイ前の準備

### ✅ アプリケーション設定
- [ ] Procfile の作成
- [ ] database.yml の PostgreSQL 対応
- [ ] Gemfile の pg gem 追加
- [ ] 環境変数の確認

### ✅ Heroku設定
- [ ] Herokuアカウント作成
- [ ] Heroku CLI インストール
- [ ] クレジットカード登録

## 🔧 デプロイ手順

### 1. 依存関係の更新
```bash
bundle install
```

### 2. Herokuアプリ作成
```bash
heroku create mobilis-ticket-app
```

### 3. データベース追加
```bash
heroku addons:create heroku-postgresql:mini
```

### 4. 環境変数設定
```bash
heroku config:set GMAIL_USERNAME=mobilis.stretch@gmail.com
heroku config:set GMAIL_APP_PASSWORD=your_app_password
heroku config:set LINE_CHANNEL_SECRET=360b1b477e3025114f7ecde7f4f05f79
heroku config:set LINE_CHANNEL_TOKEN=your_channel_token
```

### 5. デプロイ
```bash
git add .
git commit -m "Heroku対応"
git push heroku main
```

## 🗄️ デプロイ後の設定

### データベースセットアップ
```bash
heroku run rails db:migrate
heroku run rails db:seed
```

### LINEリッチメニュー設定
```bash
heroku run rails runner "LineRichMenuSetup.setup_main_menu"
```

## 🔍 動作確認

### 基本動作確認
- [ ] アプリケーション起動確認
- [ ] データベース接続確認
- [ ] 通知機能テスト
- [ ] LINEボット動作確認

### 監視・ログ確認
```bash
heroku open          # アプリケーションを開く
heroku logs --tail   # ログを確認
heroku ps            # プロセス状況確認
```

## ⚠️ 注意事項

### セキュリティ
- [ ] 環境変数の適切な設定
- [ ] 本番環境での機密情報管理
- [ ] SSL証明書の確認

### パフォーマンス
- [ ] アセットのプリコンパイル確認
- [ ] データベースのパフォーマンス確認
- [ ] ログレベルの適切な設定

## 📞 サポート

### 問題が発生した場合
1. `heroku logs --tail` でログを確認
2. Heroku公式ドキュメントを参照
3. Herokuサポートに問い合わせ

### 便利なコマンド
```bash
heroku config                    # 環境変数一覧
heroku addons                    # アドオン一覧
heroku run rails console         # Railsコンソール
heroku run rails db:reset       # データベースリセット
```

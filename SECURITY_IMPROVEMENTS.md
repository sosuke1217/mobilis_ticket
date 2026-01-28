# セキュリティ強化の実装内容

## 実装日: 2025年1月28日

## 📋 実装内容

### 1. レート制限の追加（rack-attack）

**実装ファイル**:
- `Gemfile`: `rack-attack` gemを追加
- `config/initializers/rack_attack.rb`: レート制限の設定
- `config/application.rb`: ミドルウェアの有効化

**設定内容**:
- **一般リクエスト**: 300リクエスト/5分（IP単位）
- **管理者ログイン**: 5回/20分（IP単位、メール単位）
- **一般ユーザーログイン**: 5回/20分（IP単位、メール単位）
- **LINE Botコールバック**: 100リクエスト/1分（IP単位）
- **ユーザー作成**: 10回/1時間（IP単位）
- **予約作成**: 20回/1時間（IP単位）
- **管理者操作**: 100回/1分（IP単位）

**注意**: 開発環境とテスト環境では無効化されています。

### 2. セキュリティヘッダーの統一適用

**実装ファイル**:
- `app/controllers/application_controller.rb`: `SecurityHeaders`モジュールをinclude

**設定内容**:
- `X-Frame-Options`: SAMEORIGIN
- `X-Content-Type-Options`: nosniff
- `X-XSS-Protection`: 1; mode=block
- `Referrer-Policy`: strict-origin-when-cross-origin
- `Strict-Transport-Security`: max-age=31536000; includeSubDomains（本番環境のみ）
- `Content-Security-Policy`: 適切なCSP設定

### 3. エラーハンドリングの統一

**実装ファイル**:
- `app/controllers/application_controller.rb`: `ErrorHandling`モジュールをinclude

**機能**:
- `StandardError`の統一処理
- `ActiveRecord::RecordNotFound`の統一処理
- ユーザーフレンドリーなエラーメッセージ
- ログ記録

### 4. 外部キー制約の追加

**実装ファイル**:
- `db/migrate/20250128000000_add_foreign_keys.rb`: 外部キー制約のマイグレーション

**追加された外部キー**:
- `tickets` → `users` (on_delete: :restrict)
- `tickets` → `ticket_templates` (on_delete: :nullify)
- `reservations` → `users` (on_delete: :nullify)
- `reservations` → `tickets` (on_delete: :nullify)
- `reservations` → `reservations` (parent_reservation_id, on_delete: :cascade)
- `ticket_usages` → `tickets` (on_delete: :restrict)
- `ticket_usages` → `users` (on_delete: :restrict)
- `notification_logs` → `users` (on_delete: :cascade)
- `notification_logs` → `tickets` (on_delete: :cascade)
- `notification_preferences` → `users` (on_delete: :cascade)

**注意**: SQLiteでは外部キー制約のサポートが限定的なため、PostgreSQL（本番環境）でのみ完全に機能します。

## 🚀 デプロイ手順

1. **Gemfileの更新を反映**:
   ```bash
   bundle install
   ```

2. **マイグレーションの実行**:
   ```bash
   rails db:migrate
   ```

3. **サーバーの再起動**:
   ```bash
   # 開発環境
   rails server
   
   # 本番環境（Heroku）
   git push heroku main
   ```

## ⚠️ 注意事項

1. **rack-attackの動作確認**:
   - 開発環境では無効化されているため、本番環境でテストしてください
   - レート制限に達した場合、429エラーが返されます

2. **外部キー制約**:
   - SQLite（開発環境）では外部キー制約が完全に機能しない場合があります
   - PostgreSQL（本番環境）では正常に動作します

3. **セキュリティヘッダー**:
   - すべてのコントローラーで自動的に適用されます
   - CSPの設定は必要に応じて調整してください

## 📝 今後の改善点

1. **ログの構造化**: セキュリティイベントのログを構造化
2. **監視とアラート**: レート制限の違反を監視
3. **2要素認証**: 管理者アカウントに2FAを追加
4. **セッション管理**: セッションタイムアウトの設定
5. **パスワードポリシー**: より強力なパスワード要件


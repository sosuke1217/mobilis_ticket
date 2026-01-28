class AddForeignKeys < ActiveRecord::Migration[7.2]
  def change
    # 既存の外部キー制約を確認してから追加
    # 注意: SQLiteでは外部キー制約のサポートが限定的なため、PostgreSQLでのみ有効
    
    # ticketsテーブル
    add_foreign_key :tickets, :users, on_delete: :restrict unless foreign_key_exists?(:tickets, :users)
    add_foreign_key :tickets, :ticket_templates, on_delete: :nullify unless foreign_key_exists?(:tickets, :ticket_templates)
    
    # reservationsテーブル
    add_foreign_key :reservations, :users, on_delete: :nullify unless foreign_key_exists?(:reservations, :users)
    add_foreign_key :reservations, :tickets, on_delete: :nullify unless foreign_key_exists?(:reservations, :tickets)
    add_foreign_key :reservations, :reservations, column: :parent_reservation_id, on_delete: :cascade unless foreign_key_exists?(:reservations, :reservations, column: :parent_reservation_id)
    
    # ticket_usagesテーブル（既に存在する可能性があるため確認）
    add_foreign_key :ticket_usages, :tickets, on_delete: :restrict unless foreign_key_exists?(:ticket_usages, :tickets)
    add_foreign_key :ticket_usages, :users, on_delete: :restrict unless foreign_key_exists?(:ticket_usages, :users)
    
    # notification_logsテーブル（既に存在する可能性があるため確認）
    add_foreign_key :notification_logs, :users, on_delete: :cascade unless foreign_key_exists?(:notification_logs, :users)
    add_foreign_key :notification_logs, :tickets, on_delete: :cascade unless foreign_key_exists?(:notification_logs, :tickets)
    
    # notification_preferencesテーブル（既に存在する可能性があるため確認）
    add_foreign_key :notification_preferences, :users, on_delete: :cascade unless foreign_key_exists?(:notification_preferences, :users)
  end
end


class AddStatusAndRecurrenceToReservations < ActiveRecord::Migration[7.2]
  def change
    # ステータス管理
    add_column :reservations, :status, :integer, default: 0, null: false
    add_column :reservations, :cancelled_at, :datetime
    add_column :reservations, :cancellation_reason, :text
    
    # 繰り返し予約管理
    add_column :reservations, :recurring, :boolean, default: false
    add_column :reservations, :recurring_type, :string # 'weekly', 'monthly'
    add_column :reservations, :recurring_until, :date
    add_column :reservations, :parent_reservation_id, :integer
    
    # メール管理
    add_column :reservations, :confirmation_sent_at, :datetime
    add_column :reservations, :reminder_sent_at, :datetime
    
    # インデックス追加
    add_index :reservations, :status
    add_index :reservations, :parent_reservation_id
    add_index :reservations, :start_time
  end
end

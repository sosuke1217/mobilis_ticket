class AddPerformanceIndexes < ActiveRecord::Migration[7.2]
  def change
    add_index :reservations, [:user_id, :start_time]
    add_index :reservations, [:status, :start_time]
    add_index :tickets, [:user_id, :expiry_date]
    add_index :tickets, [:user_id, :remaining_count]
    add_index :ticket_usages, [:user_id, :used_at]
    add_index :notification_logs, [:user_id, :sent_at]
  end
end

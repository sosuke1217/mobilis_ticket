class AddIntervalSettingsToApplicationSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :application_settings do |t|
      t.integer :reservation_interval_minutes, default: 15, null: false
      t.integer :business_hours_start, default: 10, null: false
      t.integer :business_hours_end, default: 20, null: false
      t.integer :slot_interval_minutes, default: 30, null: false
      t.integer :max_advance_booking_days, default: 30, null: false
      t.integer :min_advance_booking_hours, default: 24, null: false
      t.boolean :sunday_closed, default: true, null: false
      
      t.timestamps
    end
    
    # インデックスを追加（パフォーマンス向上）
    add_index :application_settings, :created_at
  end
end

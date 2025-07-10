class CreateNotificationLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :notification_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :ticket, null: false, foreign_key: true
      t.string :kind, null: false   # 例: "expiry_reminder"
      t.text :message, null: false
      t.datetime :sent_at, null: false

      t.timestamps
    end
  end
end

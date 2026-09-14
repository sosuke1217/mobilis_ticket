class CreateUserMerges < ActiveRecord::Migration[7.2]
  def change
    create_table :user_merges do |t|
      t.references :source_user, null: false, foreign_key: { to_table: :users }
      t.references :target_user, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "completed"
      t.json :source_snapshot, null: false, default: {}
      t.json :target_snapshot, null: false, default: {}
      t.json :reservation_ids, null: false, default: []
      t.json :ticket_ids, null: false, default: []
      t.json :ticket_usage_ids, null: false, default: []
      t.json :notification_log_ids, null: false, default: []
      t.datetime :undone_at
      t.timestamps
    end
  end
end

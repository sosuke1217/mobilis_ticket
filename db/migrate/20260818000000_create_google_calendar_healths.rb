class CreateGoogleCalendarHealths < ActiveRecord::Migration[7.2]
  def change
    create_table :google_calendar_healths do |t|
      t.string :key, null: false, default: "default"
      t.string :status, null: false, default: "unknown"
      t.datetime :last_success_at
      t.datetime :last_failure_at
      t.datetime :last_failure_notified_at
      t.text :last_error

      t.timestamps
    end

    add_index :google_calendar_healths, :key, unique: true
  end
end

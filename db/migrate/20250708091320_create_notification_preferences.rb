class CreateNotificationPreferences < ActiveRecord::Migration[7.2]
  def change
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.boolean :enabled, default: true

      t.timestamps
    end
  end
end

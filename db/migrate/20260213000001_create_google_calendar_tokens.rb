class CreateGoogleCalendarTokens < ActiveRecord::Migration[7.2]
  def change
    create_table :google_calendar_tokens do |t|
      t.string :user_id, null: false, index: { unique: true }
      t.text :token_data, null: false
      t.timestamps
    end
  end
end


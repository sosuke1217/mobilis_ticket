class CreateGoogleCalendarChannels < ActiveRecord::Migration[7.2]
  def change
    create_table :google_calendar_channels do |t|
      t.string :channel_id, null: false, index: { unique: true }
      t.string :resource_id, null: false
      t.datetime :expiration, null: false
      t.string :webhook_url, null: false
      t.timestamps
    end
    
    add_index :google_calendar_channels, :expiration
  end
end


class AddGoogleCalendarFieldsToReservations < ActiveRecord::Migration[7.2]
  def change
    add_column :reservations, :google_calendar_event_id, :string
    add_column :reservations, :google_calendar_synced_at, :datetime
    add_index :reservations, :google_calendar_event_id
  end
end


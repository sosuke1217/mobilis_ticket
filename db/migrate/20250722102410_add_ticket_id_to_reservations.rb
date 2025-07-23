class AddTicketIdToReservations < ActiveRecord::Migration[7.2]
  def change
    add_column :reservations, :ticket_id, :integer
  end
end

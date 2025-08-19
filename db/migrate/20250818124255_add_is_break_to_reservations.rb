class AddIsBreakToReservations < ActiveRecord::Migration[7.2]
  def change
    add_column :reservations, :is_break, :boolean, default: false, null: false
    add_index :reservations, :is_break
  end
end

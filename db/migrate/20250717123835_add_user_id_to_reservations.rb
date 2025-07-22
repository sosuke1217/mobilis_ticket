class AddUserIdToReservations < ActiveRecord::Migration[7.2]
  def change
    add_column :reservations, :user_id, :integer
  end
end

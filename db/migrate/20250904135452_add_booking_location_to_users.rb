class AddBookingLocationToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :booking_location, :string
  end
end

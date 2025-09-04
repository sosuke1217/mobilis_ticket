class AddBookingFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :booking_state, :string
    add_column :users, :booking_course, :string
  end
end

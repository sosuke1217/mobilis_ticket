class AddUserRefToTickets < ActiveRecord::Migration[7.0]
  def change
    add_reference :tickets, :user, null: true, foreign_key: true
  end
end

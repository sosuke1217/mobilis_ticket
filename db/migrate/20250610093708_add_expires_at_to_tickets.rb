class AddExpiresAtToTickets < ActiveRecord::Migration[7.2]
  def change
    add_column :tickets, :expires_at, :date
  end
end

class RemoveExpiresAtFromTickets < ActiveRecord::Migration[7.2]
  def change
    remove_column :tickets, :expires_at, :date
  end
end

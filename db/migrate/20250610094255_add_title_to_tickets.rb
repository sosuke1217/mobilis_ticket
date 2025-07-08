class AddTitleToTickets < ActiveRecord::Migration[7.2]
  def change
    add_column :tickets, :title, :string
  end
end

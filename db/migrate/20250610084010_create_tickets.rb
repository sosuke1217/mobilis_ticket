class CreateTickets < ActiveRecord::Migration[7.2]
  def change
    create_table :tickets do |t|
      t.integer :total_count
      t.integer :remaining_count
      t.datetime :purchase_date
      t.datetime :expiry_date

      t.timestamps
    end
  end
end

class CreateTicketTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_templates do |t|
      t.string :name
      t.integer :total_count
      t.integer :expiry_days

      t.timestamps
    end
  end
end

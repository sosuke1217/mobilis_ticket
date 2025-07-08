class AddPriceToTicketTemplates < ActiveRecord::Migration[7.2]
  def change
    add_column :ticket_templates, :price, :integer
  end
end

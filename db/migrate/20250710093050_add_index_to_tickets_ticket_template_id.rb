class AddIndexToTicketsTicketTemplateId < ActiveRecord::Migration[7.2]
  def change
    add_index :tickets, :ticket_template_id
  end
end

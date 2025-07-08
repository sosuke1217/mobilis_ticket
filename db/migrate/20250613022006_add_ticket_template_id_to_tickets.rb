class AddTicketTemplateIdToTickets < ActiveRecord::Migration[7.2]
  def change
    add_column :tickets, :ticket_template_id, :integer
  end
end

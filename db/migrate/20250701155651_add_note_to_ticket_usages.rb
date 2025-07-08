class AddNoteToTicketUsages < ActiveRecord::Migration[7.2]
  def change
    add_column :ticket_usages, :note, :text
  end
end

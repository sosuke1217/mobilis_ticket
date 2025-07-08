class CreateTicketUsages < ActiveRecord::Migration[7.2]
  def change
    create_table :ticket_usages do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :used_at

      t.timestamps
    end
  end
end

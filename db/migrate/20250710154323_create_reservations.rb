class CreateReservations < ActiveRecord::Migration[7.2]
  def change
    create_table :reservations do |t|
      t.string :name
      t.date :date
      t.time :time
      t.string :course
      t.text :note

      t.timestamps
    end
  end
end

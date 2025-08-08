class CreateShifts < ActiveRecord::Migration[7.2]
  def change
    create_table :shifts do |t|
      t.date :date
      t.string :shift_type
      t.time :start_time
      t.time :end_time
      t.text :notes
      t.json :breaks

      t.timestamps
    end
  end
end

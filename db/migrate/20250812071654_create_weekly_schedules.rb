class CreateWeeklySchedules < ActiveRecord::Migration[7.2]
  def change
    create_table :weekly_schedules do |t|
      t.date :week_start_date, null: false
      t.json :schedule_data, null: false, default: {}
      t.boolean :is_recurring, default: false
      t.text :notes
      t.timestamps
      
      t.index :week_start_date, unique: true
      t.index :is_recurring
    end
  end
end

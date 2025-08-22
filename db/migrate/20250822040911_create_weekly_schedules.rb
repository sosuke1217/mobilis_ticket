class CreateWeeklySchedules < ActiveRecord::Migration[7.2]
  def change
    create_table :weekly_schedules do |t|
      t.date :week_start_date, null: false
      t.json :schedule, default: {}

      t.timestamps
    end
    
    add_index :weekly_schedules, :week_start_date, unique: true
  end
end

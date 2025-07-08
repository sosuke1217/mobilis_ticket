class AddBirthDateToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :birth_date, :date
  end
end

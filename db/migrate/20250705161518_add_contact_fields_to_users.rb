class AddContactFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :postal_code, :string
    add_column :users, :address, :string
    add_column :users, :phone_number, :string
    add_column :users, :email, :string
  end
end

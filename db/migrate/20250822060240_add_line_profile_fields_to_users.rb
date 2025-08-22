class AddLineProfileFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :display_name, :string
    add_column :users, :picture_url, :text
    add_column :users, :status_message, :text
    add_column :users, :language, :string
  end
end

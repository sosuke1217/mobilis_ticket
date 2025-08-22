class RemoveLineStatusAndLanguageFromUsers < ActiveRecord::Migration[7.2]
  def change
    remove_column :users, :status_message, :string
    remove_column :users, :language, :string
  end
end

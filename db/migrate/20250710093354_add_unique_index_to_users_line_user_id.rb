class AddUniqueIndexToUsersLineUserId < ActiveRecord::Migration[7.2]
  def change
    add_index :users, :line_user_id, unique: true
  end
end

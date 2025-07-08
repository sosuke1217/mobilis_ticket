class AddAdminMemoToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :admin_memo, :text
  end
end

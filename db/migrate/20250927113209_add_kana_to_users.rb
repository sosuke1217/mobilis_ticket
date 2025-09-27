class AddKanaToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :kana, :string
  end
end

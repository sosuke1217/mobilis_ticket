class RemovePictureUrlFromUsers < ActiveRecord::Migration[7.2]
  def change
    remove_column :users, :picture_url, :text
  end
end

class AddTwoFactorToAdminUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :admin_users, :otp_secret_ciphertext, :text
    add_column :admin_users, :otp_required_for_login, :boolean, default: false, null: false
    add_column :admin_users, :otp_backup_code_digests, :json, default: [], null: false
  end
end

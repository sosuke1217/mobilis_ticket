class PopulateUserIdForTickets < ActiveRecord::Migration[7.2]
  def up
    # Skip this migration if no users exist
    if User.count == 0
      puts "⚠️ No users exist, skipping user_id population"
      return
    end

    user = User.first
    raise "Userが1人も存在しません" unless user

    Ticket.where(user_id: nil).find_each do |ticket|
      ticket.update!(user_id: user.id)
    end
  end

  def down
    # rollback不要
  end
end
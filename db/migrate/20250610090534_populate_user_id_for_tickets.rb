class PopulateUserIdForTickets < ActiveRecord::Migration[7.2]
  def up
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
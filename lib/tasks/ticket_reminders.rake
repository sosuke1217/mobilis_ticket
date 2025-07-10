# lib/tasks/ticket_reminders.rake
require_relative '../../app/services/line_notifier'

namespace :ticket do
  desc "Send LINE reminders for tickets nearing expiration"
  task send_expiry_reminders: :environment do
    today = Date.today

    [30, 7, 0].each do |days_before|
      target_date = today + days_before

      puts "[チェック] #{days_before}日前対象日: #{target_date}"

      Ticket.includes(:user)
            .where(expiry_date: target_date.beginning_of_day..target_date.end_of_day)
            .where("remaining_count > 0")
            .find_each do |ticket|

        user = ticket.user

        puts "[候補] #{user.name} のチケット: #{ticket.title}（期限: #{ticket.expiry_date}）"

        next unless user&.line_user_id
        next unless user.notification_preference&.enabled?

        puts "[通知対象] #{user.name} に通知を送ります"

        LineNotifier.send_reminder(user, ticket, days_before)
      end
      puts "[DEBUG] #{target_date} の通知対象チケット数: " +
          Ticket.where("DATE(expiry_date) = ?", target_date)
        .where("remaining_count > 0")
        .count.to_s
    end
  end
end



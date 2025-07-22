# app/services/line_notifier.rb
require 'line/bot'

class LineNotifier
  def self.send_reminder(user, ticket, days_before)
    client = Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token  = ENV['LINE_CHANNEL_TOKEN']
    end

    date_str = ticket.expiry_date.strftime('%Y/%m/%d')

    message = {
      type: "flex",
      altText: "#{ticket.title} の期限通知 / Expiry reminder",
      contents: {
        type: "bubble",
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: ticket.title,
              weight: "bold",
              size: "lg",
              wrap: true
            },
            {
              type: "text",
              text: "有効期限 / Expiry: #{date_str}",
              size: "sm",
              color: "#FF5555"
            },
            {
              type: "text",
              text: "残回数 / Remaining: #{ticket.remaining_count}回",
              size: "sm",
              color: "#FFA500"
            },
            {
              type: "text",
              text: "※ #{days_before}日前リマインド通知\n※Reminder: #{days_before} days before",
              size: "xs",
              color: "#888888",
              wrap: true
            }
          ]
        }
      }
    }

    response = client.push_message(user.line_user_id, message)
    Rails.logger.info "[LINE NOTIFY] #{user.name} にFlex通知送信 / status: #{response.code}"

    NotificationLog.create!(
      user: user,
      ticket: ticket,
      kind: "expiry_reminder",
      message: message[:altText],
      sent_at: Time.current
    )
  end
end

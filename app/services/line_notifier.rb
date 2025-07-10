# app/services/line_notifier.rb
require 'line/bot'

class LineNotifier
  def self.send_reminder(user, ticket, days_before)
    client = Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token  = ENV['LINE_CHANNEL_TOKEN']
    end

    message = {
      type: "flex",
      altText: "#{ticket.title} の期限通知",
      contents: {
        type: "bubble",
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "#{ticket.title}",
              weight: "bold",
              size: "lg",
              wrap: true
            },
            {
              type: "text",
              text: "有効期限：#{ticket.expiry_date.strftime('%Y/%m/%d')}",
              size: "sm",
              color: "#FF5555"
            },
            {
              type: "text",
              text: "残回数：#{ticket.remaining_count}回",
              size: "sm",
              color: "#FFA500"
            },
            {
              type: "text",
              text: "#{days_before}日前リマインド通知です。",
              size: "xs",
              color: "#888888"
            }
          ]
        }
      }
    }

    response = client.push_message(user.line_user_id, message)
    Rails.logger.info "[LINE NOTIFY] #{user.name} にFlex通知送信 / status: #{response.code}"

    # ✅ 通知ログを保存
    NotificationLog.create!(
      user: user,
      ticket: ticket,
      kind: "expiry_reminder",
      message: message[:altText],
      sent_at: Time.current
    )
  end
end

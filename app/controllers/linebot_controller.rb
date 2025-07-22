class LinebotController < ApplicationController
  require 'line/bot'
  protect_from_forgery with: :null_session

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']

    unless client.validate_signature(body, signature)
      head :bad_request
      return
    end

    events = client.parse_events_from(body)
    events.each do |event|
      case event
      when Line::Bot::Event::Message
        next unless event.type == Line::Bot::Event::MessageType::Text

        user_id = event['source']['userId']
        user = User.find_or_create_by!(line_user_id: user_id)

        if user.notification_preference.nil?
          user.create_notification_preference!(enabled: true)
        end

        message_text = event.message['text']

        case message_text
        when /通知オフ|notification off/i
          user.notification_preference.update(enabled: false)
          client.reply_message(event['replyToken'], {
            type: "text",
            text: "通知📴をオフにしました。\n今後は期限リマインダーが届きません。\nNotifications 🔕 turned off."
          })

        when /通知オン|notification on/i
          user.notification_preference.update(enabled: true)
          client.reply_message(event['replyToken'], {
            type: "text",
            text: "通知🔔をオンにしました。\n期限が近づいたチケットをお知らせします。\nNotifications 🔔 turned on."
          })

        else
          client.reply_message(event['replyToken'], {
            type: "text",
            text: "「通知オン」または「通知オフ」と送信すると、通知設定を変更できます。\nType 'notification on' or 'notification off' to change your notification settings."
          })
        end

      when Line::Bot::Event::Postback
        Rails.logger.info "[LINE POSTBACK] data=#{event['postback']['data']}, user=#{event['source']['userId']}"

        user_id = event['source']['userId']
        user = User.find_or_create_by!(line_user_id: user_id)
    
        data = event['postback']['data']
    
        case data
        when "check_tickets"
          tickets = user.tickets.where("remaining_count > 0 AND expiry_date >= ?", Time.zone.today)
          if tickets.any?
            bubbles = tickets.map do |t|
              expiry_soon = t.expiry_date <= Time.zone.today + 30.days
              low_remaining = t.remaining_count == 2
        
              contents = [
                {
                  type: "text",
                  text: t.title,
                  weight: "bold",
                  size: "lg",
                  wrap: true
                },
                {
                  type: "text",
                  text: "残り/Remaining：#{t.remaining_count}回",
                  size: "md",
                  margin: "md"
                }.merge(low_remaining ? { color: "#FFA500" } : {}),
                {
                  type: "text",
                  text: "期限/Exp：#{t.expiry_date.strftime('%Y/%m/%d')}",
                  size: "sm",
                  margin: "sm",
                  color: expiry_soon ? "#FF5555" : "#888888"
                }
              ]
        
              {
                type: "bubble",
                body: {
                  type: "box",
                  layout: "vertical",
                  contents: contents
                }
              }
            end
        
            response = client.reply_message(event['replyToken'], { 
              type: "flex",
              altText: "使用可能な回数券一覧 / Available Tickets",
              contents: {
                type: "carousel",
                contents: bubbles
              }
            })
            Rails.logger.info "[LINE API] status: #{response.code}, body: #{response.body}"
          else
            response = client.reply_message(event['replyToken'], {
              type: "text",
              text: "使用可能な回数券が見つかりません / No available tickets found."
            })
            Rails.logger.info "[LINE API] status: #{response.code}, body: #{response.body}"
          end
    
        when "usage_history"
          usages = user.ticket_usages.order(used_at: :desc).limit(12)
        
          if usages.any?
            lines = usages.map do |usage|
              ticket_title = usage.ticket.title
              date = usage.used_at.strftime('%Y/%m/%d')
              "・#{date}：#{ticket_title}"
            end
        
            message = "🕓 直近12回の使用履歴 / Recent 12 Usage Records\n" + lines.join("\n")
        
            response = client.reply_message(event['replyToken'], {
              type: "text",
              text: message
            })
          else
            response = client.reply_message(event['replyToken'], {
              type: "text",
              text: "使用履歴が見つかりません / No usage records found."
            })
          end
        
          Rails.logger.info "[LINE API] status: #{response.code}, body: #{response.body}"
    
        when "booking"
          response = client.reply_message(event['replyToken'], {
            type: "text",
            text: "📅 ご予約はこちらから：https://mobilis-stretch.com/book"
          })
          Rails.logger.info "[LINE API] status: #{response.code}, body: #{response.body}"
    
        when "news"
          response = client.reply_message(event['replyToken'], {
            type: "text",
            text: "📰 最新情報はこちら：https://mobilis-stretch.com/news"
          })
          Rails.logger.info "[LINE API] status: #{response.code}, body: #{response.body}"
    
        when "reviews"
          response = client.reply_message(event['replyToken'], {
            type: "text",
            text: "⭐️ ご感想はこちら：https://mobilis-stretch.com/reviews"
          })
          Rails.logger.info "[LINE API] status: #{response.code}, body: #{response.body}"
    
        else
          response = client.reply_message(event['replyToken'], {
            type: "text",
            text: "⚠️ 未知のアクション: #{data}"
          })
          Rails.logger.info "[LINE API] status: #{response.code}, body: #{response.body}"
        end
      end
    end
  end

  private

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end
  end
end

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
        # （今までの text 処理）
      when Line::Bot::Event::Postback
        Rails.logger.info "[LINE POSTBACK] data=#{event['postback']['data']}, user=#{event['source']['userId']}"

        user_id = event['source']['userId']
        user = User.find_or_create_by!(line_user_id: user_id)
    
        data = event['postback']['data']
    
        case data
        when "check_tickets"
          # ✅ 残数確認処理を再利用
          tickets = user.tickets.where("remaining_count > 0 AND expiry_date >= ?", Date.today)
          if tickets.any?
            bubbles = tickets.map do |t|
              expiry_soon = t.expiry_date <= Date.today + 30.days
              low_remaining = t.remaining_count == 2
    
              contents = [
                { type: "text", text: t.title, weight: "bold", size: "lg", wrap: true },
                {
                  type: "text",
                  text: "残り：#{t.remaining_count}回",
                  size: "md",
                  margin: "md"
                }.merge(low_remaining ? { color: "#FFA500" } : {}),
                {
                  type: "text",
                  text: "期限：#{t.expiry_date.strftime('%Y/%m/%d')}",
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
              altText: "使用可能な回数券一覧",
              contents: {
                type: "carousel",
                contents: bubbles
              }
            })
            Rails.logger.info "[LINE API] status: #{response.code}, body: #{response.body}"
          else
            response = client.reply_message(event['replyToken'], {
              type: "text",
              text: "使用可能な回数券が見つかりません。"
            })
            Rails.logger.info "[LINE API] status: #{response.code}, body: #{response.body}"
          end
    
        when "usage_history"
          # ✅ 履歴（ダミーメッセージで仮対応）
          response = client.reply_message(event['replyToken'], {
            type: "text",
            text: "🕓 最近の使用履歴は現在準備中です。"
          })
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

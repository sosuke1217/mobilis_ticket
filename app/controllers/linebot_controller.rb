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
      next unless event.is_a?(Line::Bot::Event::Message)
      next unless event.type == Line::Bot::Event::MessageType::Text

      user_id = event['source']['userId']
      user = User.find_or_create_by!(line_user_id: user_id)
      if user.name.blank?
        response = client.get_profile(user_id)
        if response.is_a?(Net::HTTPSuccess)
          profile = JSON.parse(response.body)
          user.update(name: profile['displayName'])
        end
      end

      # 使用可能なチケットを検索（有効期限と残回数考慮）
      ticket = user.tickets.where("remaining_count > 0 AND expiry_date >= ?", Date.today).first

      case event.message['text']
      when /消費/
        if ticket&.use_one
          TicketUsage.create!(
            ticket: ticket,
            user: user,
            used_at: Time.current
          )
          reply_text = "回数券を1回分消費しました。残り#{ticket.remaining_count}回です。"
        else
          reply_text = "回数券の消費に失敗しました。残数や有効期限を確認してください。"
        end
      when /残数/
        if ticket
          reply_text = "回数券の残り回数は#{ticket.remaining_count}回です。"
        else
          reply_text = "回数券が登録されていません。"
        end
      else
        reply_text = "「消費」か「残数」と送信してください。"
      end

      message = {
        type: 'text',
        text: reply_text
      }
      client.reply_message(event['replyToken'], message)
    end

    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end
  end
end

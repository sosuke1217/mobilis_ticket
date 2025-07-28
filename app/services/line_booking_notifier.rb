# app/services/line_booking_notifier.rb
class LineBookingNotifier
  def self.new_booking_request(reservation)
    client = Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end

    user = reservation.user
    return unless user.line_user_id

    message = build_booking_request_message(reservation)
    
    response = client.push_message(user.line_user_id, message)
    Rails.logger.info "[LINE BOOKING] 予約リクエスト通知送信: #{response.code}"
    
    # 通知ログを記録
    create_notification_log(user, reservation, 'booking_request')
  end

  def self.booking_confirmed(reservation)
    client = Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end

    user = reservation.user
    return unless user.line_user_id

    message = build_confirmation_message(reservation)
    
    response = client.push_message(user.line_user_id, message)
    Rails.logger.info "[LINE BOOKING] 予約確定通知送信: #{response.code}"
    
    create_notification_log(user, reservation, 'booking_confirmed')
  end

  private

  def self.build_booking_request_message(reservation)
    user = reservation.user
    
    {
      type: "flex",
      altText: "予約リクエストを承りました",
      contents: {
        type: "bubble",
        hero: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "予約リクエスト受付",
              weight: "bold",
              size: "xl",
              color: "#1976d2"
            },
            {
              type: "text",
              text: "確認のご連絡をお待ちください",
              size: "sm",
              color: "#666666"
            }
          ],
          paddingAll: "20px"
        },
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "📋 予約内容",
              weight: "bold",
              size: "md",
              margin: "md"
            },
            {
              type: "separator",
              margin: "md"
            },
            {
              type: "box",
              layout: "vertical",
              contents: [
                create_info_row("コース", reservation.course),
                create_info_row("希望日時", reservation.start_time&.strftime('%m/%d %H:%M')),
                create_info_row("お名前", user.name),
                create_info_row("ご住所", truncate_address(user.address))
              ],
              margin: "md"
            },
            {
              type: "text",
              text: "担当者より24時間以内にご連絡いたします。しばらくお待ちください。",
              size: "sm",
              color: "#666666",
              wrap: true,
              margin: "md"
            }
          ]
        },
        footer: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "button",
              style: "secondary",
              action: {
                type: "postback",
                label: "予約をキャンセル",
                data: "cancel_booking_#{reservation.id}"
              }
            }
          ]
        }
      }
    }
  end

  def self.build_confirmation_message(reservation)
    {
      type: "flex",
      altText: "予約が確定しました",
      contents: {
        type: "bubble",
        hero: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "予約確定",
              weight: "bold",
              size: "xl",
              color: "#4caf50"
            },
            {
              type: "text",
              text: "ご予約が確定いたしました",
              size: "sm",
              color: "#666666"
            }
          ],
          paddingAll: "20px"
        },
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "📅 確定内容",
              weight: "bold",
              size: "md"
            },
            {
              type: "separator",
              margin: "md"
            },
            {
              type: "box",
              layout: "vertical",
              contents: [
                create_info_row("日時", reservation.start_time.strftime('%m/%d(%a) %H:%M〜')),
                create_info_row("コース", reservation.course),
                create_info_row("場所", truncate_address(reservation.user.address))
              ],
              margin: "md"
            },
            {
              type: "text",
              text: "当日は5分前にお伺いいたします。よろしくお願いいたします。",
              size: "sm",
              color: "#666666",
              wrap: true,
              margin: "lg"
            }
          ]
        }
      }
    }
  end

  def self.create_info_row(label, value)
    {
      type: "box",
      layout: "baseline",
      contents: [
        {
          type: "text",
          text: label,
          size: "sm",
          color: "#666666",
          flex: 2
        },
        {
          type: "text",
          text: value.to_s,
          size: "sm",
          wrap: true,
          flex: 3
        }
      ],
      margin: "sm"
    }
  end

  def self.truncate_address(address)
    return "" unless address
    address.length > 20 ? "#{address[0..20]}..." : address
  end

  def self.create_notification_log(user, reservation, kind)
    # 既存のNotificationLogテーブルを活用
    # ただし、reservationに関連するticketがない場合は作成しない
    return unless reservation.ticket

    NotificationLog.create!(
      user: user,
      ticket: reservation.ticket,
      kind: kind,
      message: "予約#{kind}通知",
      sent_at: Time.current
    )
  rescue => e
    Rails.logger.error "通知ログ作成エラー: #{e.message}"
  end
end
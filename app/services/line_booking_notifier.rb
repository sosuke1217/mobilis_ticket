# app/services/line_booking_notifier.rb の強化版

class LineBookingNotifier
  def self.new_booking_request(reservation)
    client = Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end
  
    user = reservation.user
    return unless user.line_user_id
  
    retries = 0
    max_retries = 3
  
    begin
      message = build_booking_request_message(reservation)
      response = client.push_message(user.line_user_id, message)
      
      Rails.logger.info "[LINE BOOKING] 予約リクエスト通知送信: #{response.code}"
      create_notification_log(user, reservation, 'booking_request')
      
    rescue Net::TimeoutError, Net::ReadTimeout => e
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "LINE API timeout (#{retries}/#{max_retries}): #{e.message}"
        sleep(2 * retries)
        retry
      else
        Rails.logger.error "LINE API failed after #{max_retries} retries: #{e.message}"
        # メールでフォールバック
        send_email_fallback(reservation) if user.email.present?
      end
    rescue => e
      Rails.logger.error "LINE notification failed: #{e.message}"
      send_email_fallback(reservation) if user.email.present?
    end
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

  # 🆕 予約リマインダー送信
  def self.send_reminder(reservation)
    client = Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end

    user = reservation.user
    return unless user.line_user_id

    message = build_reminder_message(reservation)
    
    response = client.push_message(user.line_user_id, message)
    Rails.logger.info "[LINE BOOKING] リマインダー送信: #{response.code}"
    
    # リマインダー送信済みフラグを更新
    reservation.update_column(:reminder_sent_at, Time.current)
  end

  # 🆕 キャンセル通知送信
  def self.send_cancellation_notification(reservation)
    client = Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end

    user = reservation.user
    return unless user.line_user_id

    message = build_cancellation_message(reservation)
    
    response = client.push_message(user.line_user_id, message)
    Rails.logger.info "[LINE BOOKING] キャンセル通知送信: #{response.code}"
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
                create_info_row("お名前", user.name)
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
                label: "この予約をキャンセル",
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
                create_info_row("コース", reservation.course)
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
                data: "cancel_confirmed_booking_#{reservation.id}"
              }
            }
          ]
        }
      }
    }
  end

  # 🆕 リマインダーメッセージ
  def self.build_reminder_message(reservation)
    {
      type: "flex",
      altText: "明日のご予約リマインダー",
      contents: {
        type: "bubble",
        hero: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "🔔 予約リマインダー",
              weight: "bold",
              size: "xl",
              color: "#ff9800"
            },
            {
              type: "text",
              text: "明日のご予約についてお知らせします",
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
              text: "📅 明日のご予約",
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
                create_info_row("日時", reservation.start_time.strftime('%m/%d(%a) %H:%M〜%H:%M')),
                create_info_row("コース", reservation.course)
              ],
              margin: "md"
            },
            {
              type: "text",
              text: "ご予約時間の5分前にお伺いいたします。",
              size: "sm",
              color: "#666666",
              wrap: true,
              margin: "lg"
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
                label: "やむを得ずキャンセル",
                data: "urgent_cancel_#{reservation.id}"
              }
            }
          ]
        }
      }
    }
  end

  # 🆕 キャンセル通知メッセージ
  def self.build_cancellation_message(reservation)
    {
      type: "flex",
      altText: "予約がキャンセルされました",
      contents: {
        type: "bubble",
        hero: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "❌ 予約キャンセル",
              weight: "bold",
              size: "xl",
              color: "#dc3545"
            },
            {
              type: "text",
              text: "Reservation Cancelled",
              size: "sm",
              color: "#999999",
              margin: "xs"
            },
            {
              type: "text",
              text: "ご予約がキャンセルされました",
              size: "sm",
              color: "#666666",
              margin: "sm"
            },
            {
              type: "text",
              text: "Your reservation has been cancelled",
              size: "sm",
              color: "#999999",
              margin: "xs"
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
              text: "📋 キャンセルされた予約",
              weight: "bold",
              size: "md"
            },
            {
              type: "text",
              text: "Cancelled Reservation",
              size: "sm",
              color: "#999999",
              margin: "xs"
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
                create_info_row("コース", reservation.course.to_s.gsub(/分$/, '') + "min")
              ],
              margin: "md"
            },
            {
              type: "text",
              text: "またのご利用をお待ちしております。\n再予約をご希望の場合は、ご連絡ください。",
              size: "sm",
              color: "#666666",
              wrap: true,
              margin: "lg"
            },
            {
              type: "text",
              text: "We look forward to serving you again.\nPlease contact us if you would like to make a new reservation.",
              size: "sm",
              color: "#999999",
              wrap: true,
              margin: "xs"
            }
          ]
        },
        footer: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "button",
              style: "primary",
              action: {
                type: "postback",
                label: "新しい予約をする",
                data: "booking"
              }
            },
            {
              type: "text",
              text: "Make New Reservation",
              size: "sm",
              color: "#999999",
              align: "center",
              margin: "xs"
            }
          ]
        }
      }
    }
  end

  def self.create_info_row(label, value, is_english = false)
    {
      type: "box",
      layout: "baseline",
      contents: [
        {
          type: "text",
          text: label,
          size: "sm",
          color: is_english ? "#999999" : "#666666",
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

  def self.send_email_fallback(reservation)
    ReservationMailer.confirmation(reservation).deliver_later
    Rails.logger.info "Sent email fallback for reservation #{reservation.id}"
  end
  
end
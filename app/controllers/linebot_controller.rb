# app/controllers/linebot_controller.rb の改善版

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
        handle_text_message(user, message_text, event['replyToken'])

      when Line::Bot::Event::Postback
        Rails.logger.info "[LINE POSTBACK] data=#{event['postback']['data']}, user=#{event['source']['userId']}"

        user_id = event['source']['userId']
        user = User.find_or_create_by!(line_user_id: user_id)
        
        data = event['postback']['data']
        handle_postback_action(user, data, event['replyToken'])
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

  def handle_text_message(user, message_text, reply_token)
    case message_text
    when /通知オフ|notification off/i
      user.notification_preference.update(enabled: false)
      send_reply(reply_token, {
        type: "text",
        text: "通知📴をオフにしました。\n今後は期限リマインダーが届きません。\nNotifications 🔕 turned off."
      })

    when /通知オン|notification on/i
      user.notification_preference.update(enabled: true)
      send_reply(reply_token, {
        type: "text",
        text: "通知🔔をオンにしました。\n期限が近づいたチケットをお知らせします。\nNotifications 🔔 turned on."
      })

    when /予約|booking|ご予約/i
      send_booking_options(user, reply_token)

    when /40分|40分コース/i
      start_booking_flow(user, reply_token, "40分コース")

    when /60分|60分コース/i
      start_booking_flow(user, reply_token, "60分コース")

    when /80分|80分コース/i
      start_booking_flow(user, reply_token, "80分コース")

    else
      send_default_help(reply_token)
    end
  end

  def handle_postback_action(user, data, reply_token)
    case data
    when "check_tickets"
      send_ticket_status(user, reply_token)

    when "usage_history"
      send_usage_history(user, reply_token)

    when "booking"
      send_booking_options(user, reply_token)

    when "news"
      send_reply(reply_token, {
        type: "text",
        text: "📰 最新情報はこちら：https://mobilis-stretch.com/news"
      })

    when "reviews"
      send_reply(reply_token, {
        type: "text",
        text: "⭐️ ご感想はこちら：https://mobilis-stretch.com/reviews"
      })

    when /^book_(\d+)min$/
      course = "#{$1}分コース"
      start_booking_flow(user, reply_token, course)

    when /^select_date_(.+)_(.+)$/
      course = $1
      date = $2
      send_available_times(user, reply_token, course, date)

    when /^confirm_booking_(.+)_(.+)_(.+)$/
      course = $1
      date = $2
      time = $3
      create_booking(user, reply_token, course, date, time)

    when /^cancel_booking_(\d+)$/
      reservation_id = $1.to_i
      handle_booking_cancellation(user, reply_token, reservation_id, "お客様都合によるキャンセル")

    when /^cancel_confirmed_booking_(\d+)$/
      reservation_id = $1.to_i
      handle_booking_cancellation(user, reply_token, reservation_id, "お客様都合によるキャンセル")

    when /^urgent_cancel_(\d+)$/
      reservation_id = $1.to_i
      send_cancellation_reason_options(user, reply_token, reservation_id)

    else
      send_reply(reply_token, {
        type: "text",
        text: "⚠️ 未知のアクション: #{data}"
      })
    end
  end

  # 🆕 予約オプションを送信
  def send_booking_options(user, reply_token)
    message = {
      type: "flex",
      altText: "ご予約・コース選択",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "📅 ご予約",
              weight: "bold",
              size: "xl",
              color: "#1976d2"
            },
            {
              type: "text",
              text: "ご希望のコースをお選びください",
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
            create_course_button("40分コース", "¥8,000", "book_40min"),
            create_course_button("60分コース", "¥12,000", "book_60min"),
            create_course_button("80分コース", "¥16,000", "book_80min")
          ],
          spacing: "md"
        },
        footer: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "※料金は出張費込み\n※広尾エリア専門",
              size: "xs",
              color: "#999999",
              wrap: true
            }
          ]
        }
      }
    }

    send_reply(reply_token, message)
  end

  # 🆕 予約フローを開始
  def start_booking_flow(user, reply_token, course)
    # ユーザー情報が不完全な場合は情報入力を促す
    unless user.name.present? && user.phone_number.present? && user.address.present?
      send_user_info_request(user, reply_token, course)
      return
    end

    # 利用可能な日付を表示
    available_dates = get_available_dates(7) # 今日から7日間
    
    if available_dates.empty?
      send_reply(reply_token, {
        type: "text",
        text: "申し訳ございません。現在予約可能な日程がございません。\nお電話でお問い合わせください: 03-1234-5678"
      })
      return
    end

    message = {
      type: "flex",
      altText: "日程選択 - #{course}",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "📅 日程選択",
              weight: "bold",
              size: "lg"
            },
            {
              type: "text",
              text: "選択コース: #{course}",
              size: "sm",
              color: "#1976d2"
            }
          ]
        },
        body: {
          type: "box",
          layout: "vertical",
          contents: available_dates.map { |date|
            {
              type: "button",
              style: "secondary",
              action: {
                type: "postback",
                label: date.strftime('%m/%d (%a)'),
                data: "select_date_#{course}_#{date.strftime('%Y-%m-%d')}"
              }
            }
          },
          spacing: "sm"
        }
      }
    }

    send_reply(reply_token, message)
  end

  # 🆕 ユーザー情報入力を促す
  def send_user_info_request(user, reply_token, course)
    missing_info = []
    missing_info << "お名前" unless user.name.present?
    missing_info << "お電話番号" unless user.phone_number.present?
    missing_info << "ご住所" unless user.address.present?

    message = {
      type: "flex",
      altText: "ユーザー情報の入力が必要です",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "📝 情報入力",
              weight: "bold",
              size: "lg",
              color: "#dc3545"
            }
          ]
        },
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "ご予約には以下の情報が必要です：",
              wrap: true
            },
            {
              type: "text",
              text: "• #{missing_info.join('\n• ')}",
              wrap: true,
              color: "#dc3545",
              margin: "md"
            },
            {
              type: "text",
              text: "下記フォームからご入力ください",
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
              style: "primary",
              action: {
                type: "uri",
                label: "情報入力フォームへ",
                uri: "#{ENV.fetch('APP_HOST', 'https://mobilis-stretch.com')}/public/bookings/new"
              }
            }
          ]
        }
      }
    }

    send_reply(reply_token, message)
  end

  # 🆕 利用可能な時間を送信
  def send_available_times(user, reply_token, course, date_str)
    date = Date.parse(date_str)
    duration = get_duration_from_course(course)
    
    available_slots = get_available_time_slots(date, duration)
    
    if available_slots.empty?
      send_reply(reply_token, {
        type: "text",
        text: "申し訳ございません。#{date.strftime('%m/%d')}は空きがございません。\n別の日程をお選びください。"
      })
      return
    end

    message = {
      type: "flex",
      altText: "時間選択 - #{date.strftime('%m/%d')}",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "⏰ 時間選択",
              weight: "bold",
              size: "lg"
            },
            {
              type: "text",
              text: "#{date.strftime('%m/%d (%a)')} - #{course}",
              size: "sm",
              color: "#1976d2"
            }
          ]
        },
        body: {
          type: "box",
          layout: "vertical",
          contents: available_slots.map { |slot|
            {
              type: "button",
              style: "secondary",
              action: {
                type: "postback",
                label: "#{slot[:start_time].strftime('%H:%M')} - #{slot[:end_time].strftime('%H:%M')}",
                data: "confirm_booking_#{course}_#{date_str}_#{slot[:start_time].strftime('%H:%M')}"
              }
            }
          },
          spacing: "sm"
        }
      }
    }

    send_reply(reply_token, message)
  end

  # 🆕 予約を作成
  def create_booking(user, reply_token, course, date_str, time_str)
    begin
      date = Date.parse(date_str)
      start_time = Time.zone.parse("#{date} #{time_str}")
      duration = get_duration_from_course(course)
      end_time = start_time + duration.minutes

      # 重複チェック
      if Reservation.active.where('start_time < ? AND end_time > ?', end_time, start_time).exists?
        send_reply(reply_token, {
          type: "text",
          text: "申し訳ございません。選択された時間は既に予約が入っております。\n別の時間をお選びください。"
        })
        return
      end

      reservation = Reservation.create!(
        name: user.name,
        start_time: start_time,
        end_time: end_time,
        course: course,
        status: :tentative, # 仮予約
        user: user,
        note: "LINEからの予約"
      )

      # 予約確認メッセージ
      message = {
        type: "flex",
        altText: "予約完了",
        contents: {
          type: "bubble",
          header: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: "✅ 予約リクエスト完了",
                weight: "bold",
                size: "lg",
                color: "#28a745"
              }
            ]
          },
          body: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: "以下の内容で予約リクエストを承りました：",
                wrap: true
              },
              {
                type: "separator",
                margin: "md"
              },
              create_info_row("日時", "#{start_time.strftime('%m/%d (%a) %H:%M')} - #{end_time.strftime('%H:%M')}"),
              create_info_row("コース", course),
              create_info_row("お名前", user.name),
              create_info_row("ご住所", truncate_address(user.address)),
              {
                type: "separator",
                margin: "md"
              },
              {
                type: "text",
                text: "24時間以内に確認のご連絡をいたします。\nしばらくお待ちください。",
                size: "sm",
                color: "#666666",
                wrap: true,
                margin: "md"
              }
            ]
          }
        }
      }

      send_reply(reply_token, message)

      # 管理者に通知
      AdminNotificationJob.perform_later(reservation) rescue nil

    rescue => e
      Rails.logger.error "LINE予約作成エラー: #{e.message}"
      send_reply(reply_token, {
        type: "text",
        text: "申し訳ございません。予約処理中にエラーが発生いたしました。\nお電話でお問い合わせください: 03-1234-5678"
      })
    end
  end

  # 🆕 予約キャンセル処理
  def handle_booking_cancellation(user, reply_token, reservation_id, reason)
    begin
      reservation = user.reservations.find(reservation_id)
      
      unless reservation.cancellable?
        send_reply(reply_token, {
          type: "text",
          text: "申し訳ございません。この予約はキャンセルできません。\nお問い合わせ: 03-1234-5678"
        })
        return
      end

      reservation.cancel!(reason)
      
      # キャンセル完了メッセージ
      message = {
        type: "flex",
        altText: "予約をキャンセルしました",
        contents: {
          type: "bubble",
          header: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: "✅ キャンセル完了",
                weight: "bold",
                size: "lg",
                color: "#dc3545"
              }
            ]
          },
          body: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: "以下の予約をキャンセルいたしました：",
                wrap: true
              },
              {
                type: "separator",
                margin: "md"
              },
              create_info_row("日時", "#{reservation.start_time.strftime('%m/%d (%a) %H:%M')} - #{reservation.end_time.strftime('%H:%M')}"),
              create_info_row("コース", reservation.course),
              {
                type: "separator",
                margin: "md"
              },
              {
                type: "text",
                text: "またのご利用をお待ちしております。",
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
                style: "primary",
                action: {
                  type: "postback",
                  label: "新しい予約をする",
                  data: "booking"
                }
              }
            ]
          }
        }
      }

      send_reply(reply_token, message)

      # 管理者に通知
      Rails.logger.info "LINE予約キャンセル: 予約ID #{reservation.id}, ユーザー: #{user.name}"

    rescue ActiveRecord::RecordNotFound
      send_reply(reply_token, {
        type: "text",
        text: "予約が見つかりませんでした。"
      })
    rescue => e
      Rails.logger.error "LINE予約キャンセルエラー: #{e.message}"
      send_reply(reply_token, {
        type: "text",
        text: "キャンセル処理中にエラーが発生いたしました。\nお電話でお問い合わせください: 03-1234-5678"
      })
    end
  end

  # 🆕 キャンセル理由選択
  def send_cancellation_reason_options(user, reply_token, reservation_id)
    message = {
      type: "flex",
      altText: "キャンセル理由を選択してください",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "キャンセル理由",
              weight: "bold",
              size: "lg"
            }
          ]
        },
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "キャンセルの理由をお選びください：",
              wrap: true
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
                label: "体調不良",
                data: "cancel_with_reason_#{reservation_id}_体調不良"
              }
            },
            {
              type: "button",
              style: "secondary",
              action: {
                type: "postback",
                label: "急用",
                data: "cancel_with_reason_#{reservation_id}_急用"
              }
            },
            {
              type: "button",
              style: "secondary",
              action: {
                type: "postback",
                label: "その他",
                data: "cancel_with_reason_#{reservation_id}_その他の理由"
              }
            }
          ],
          spacing: "sm"
        }
      }
    }

    send_reply(reply_token, message)
  end

  # 既存のメソッドは保持...
  def send_ticket_status(user, reply_token)
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
  
      response = client.reply_message(reply_token, { 
        type: "flex",
        altText: "使用可能な回数券一覧 / Available Tickets",
        contents: {
          type: "carousel",
          contents: bubbles
        }
      })
      Rails.logger.info "[LINE API] status: #{response.code}, body: #{response.body}"
    else
      response = client.reply_message(reply_token, {
        type: "text",
        text: "使用可能な回数券が見つかりません / No available tickets found."
      })
      Rails.logger.info "[LINE API] status: #{response.code}, body: #{response.body}"
    end
  end

  def send_usage_history(user, reply_token)
    usages = user.ticket_usages.order(used_at: :desc).limit(12)
  
    if usages.any?
      lines = usages.map do |usage|
        ticket_title = usage.ticket.title
        date = usage.used_at.strftime('%Y/%m/%d')
        "・#{date}：#{ticket_title}"
      end
  
      message = "🕓 直近12回の使用履歴 / Recent 12 Usage Records\n" + lines.join("\n")
  
      response = client.reply_message(reply_token, {
        type: "text",
        text: message
      })
    else
      response = client.reply_message(reply_token, {
        type: "text",
        text: "使用履歴が見つかりません / No usage records found."
      })
    end
  
    Rails.logger.info "[LINE API] status: #{response.code}, body: #{response.body}"
  end

  def send_default_help(reply_token)
    send_reply(reply_token, {
      type: "text",
      text: "以下のコマンドをお試しください：\n\n" \
            "📅「予約」→ 新規予約\n" \
            "🎫「チケット」→ チケット残数確認\n" \
            "🔔「通知オン/オフ」→ 通知設定\n\n" \
            "または下のメニューからもご利用いただけます。"
    })
  end

  # ヘルパーメソッド
  def send_reply(reply_token, message)
    client.reply_message(reply_token, message)
  end

  def create_course_button(course_name, price, data)
    {
      type: "button",
      style: "secondary",
      action: {
        type: "postback",
        label: "#{course_name} #{price}",
        data: data
      }
    }
  end

  def create_info_row(label, value)
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

  def truncate_address(address)
    return "" unless address
    address.length > 20 ? "#{address[0..20]}..." : address
  end

  def get_duration_from_course(course)
    case course
    when "40分コース" then 40
    when "60分コース" then 60
    when "80分コース" then 80
    else 60
    end
  end

  def get_available_dates(days_ahead)
    dates = []
    (1..days_ahead).each do |i|
      date = Date.current + i.days
      # 営業日チェック（例：日曜日は休み）
      next if date.sunday?
      
      # その日に空きがあるかチェック
      if has_available_slots_on_date(date)
        dates << date
      end
    end
    dates
  end

  def has_available_slots_on_date(date)
    # 簡単なチェック：その日の予約数が一定数以下なら空きありとする
    reservations_count = Reservation.active
      .where(start_time: date.beginning_of_day..date.end_of_day)
      .count
    
    reservations_count < 8 # 1日最大8枠と仮定
  end

  def get_available_time_slots(date, duration)
    # Public::BookingsControllerと同じロジックを使用
    opening_time = Time.zone.parse("#{date} 10:00")
    closing_time = Time.zone.parse("#{date} 21:00")
    slot_interval = 30.minutes
    available_slots = []
    
    current_time = opening_time
    while current_time + duration.minutes <= closing_time
      end_time = current_time + duration.minutes
      
      unless Reservation.active.where('start_time < ? AND end_time > ?', end_time, current_time).exists?
        available_slots << {
          start_time: current_time,
          end_time: end_time
        }
      end
      
      current_time += slot_interval
    end
    
    available_slots
  end
end
# app/controllers/linebot_controller.rb の改善版

class LinebotController < ApplicationController
  skip_before_action :verify_authenticity_token
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
        user = find_or_create_user_with_profile(user_id)

        if user.notification_preference.nil?
          user.create_notification_preference!(enabled: true)
        end

        message_text = event.message['text']
        handle_text_message(user, message_text, event['replyToken'])

      when Line::Bot::Event::Postback
        Rails.logger.info "[LINE POSTBACK] data=#{event['postback']['data']}, user=#{event['source']['userId']}"

        user_id = event['source']['userId']
        user = find_or_create_user_with_profile(user_id)
        
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
      send_news_menu(reply_token)

    when "reviews"
      send_reviews_menu(reply_token)

    when /^select_time_period_(.+)_(.+)_(.+)$/
      course = $1
      date = $2
      period = $3
      handle_time_period_selection(user, reply_token, course, date, period)

    when /^select_date_(.+)_(.+)$/
      course = $1
      date = $2
      send_available_times(user, reply_token, course, date)
  
    when /^confirm_booking_(.+)_(.+)_(.+)$/
      course = $1
      date = $2
      time = $3
      create_booking(user, reply_token, course, date, time)  

    when /^book_(\d+)min$/
      course = "#{$1}分コース"
      start_booking_flow(user, reply_token, course)

    when /^cancel_booking_(\d+)$/
      reservation_id = $1.to_i
      handle_booking_cancellation(user, reply_token, reservation_id, "お客様都合によるキャンセル")

    when /^cancel_confirmed_booking_(\d+)$/
      reservation_id = $1.to_i
      handle_booking_cancellation(user, reply_token, reservation_id, "お客様都合によるキャンセル")

    when /^cancel_with_reason_(\d+)_(.+)$/
      reservation_id = $1.to_i
      reason = $2
      handle_booking_cancellation(user, reply_token, reservation_id, reason)
    
    when /^urgent_cancel_(\d+)$/
      reservation_id = $1.to_i
      send_cancellation_reason_options(user, reply_token, reservation_id)

    when "post_review"
      # Googleレビューに変更したため、このアクションは不要
      send_reply(reply_token, {
        type: "text",
        text: "Googleレビュー機能に変更されました。メニューから「Googleレビュー」をお選びください。"
      })

    when "view_reviews"
      # Googleレビューに変更したため、このアクションは不要
      send_reply(reply_token, {
        type: "text",
        text: "Googleレビュー機能に変更されました。メニューから「Googleレビュー」をお選びください。"
      })

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
    begin
      date = Date.parse(date_str)
      duration = get_duration_from_course(course)
      
      available_slots = get_available_time_slots(date, duration)
      
      if available_slots.empty?
        send_reply(reply_token, {
          type: "text",
          text: "申し訳ございません。#{date.strftime('%m/%d')}（#{course}）は空きがございません。\n別の日時をお選びください。"
        })
        return
      end
  
      # 利用可能スロットが多い場合は複数のメッセージに分割
      if available_slots.length > 10
        send_paginated_time_slots(user, reply_token, course, date_str, available_slots)
      else
        send_single_time_slots_message(user, reply_token, course, date_str, available_slots)
      end
      
    rescue Date::Error
      send_reply(reply_token, {
        type: "text",
        text: "日付の形式が正しくありません。もう一度お試しください。"
      })
    rescue => e
      Rails.logger.error "send_available_times error: #{e.message}"
      send_reply(reply_token, {
        type: "text",
        text: "申し訳ございません。システムエラーが発生しました。しばらく後にお試しください。"
      })
    end
  end

  def send_single_time_slots_message(user, reply_token, course, date_str, available_slots)
    date = Date.parse(date_str)
    
    time_buttons = available_slots.map do |slot|
      {
        type: "button",
        style: "secondary",
        action: {
          type: "postback",
          label: "#{slot[:start_time].strftime('%H:%M')} - #{slot[:end_time].strftime('%H:%M')}",
          data: "confirm_booking_#{course}_#{date_str}_#{slot[:start_time].strftime('%H:%M')}"
        }
      }
    end
  
    message = {
      type: "flex",
      altText: "利用可能時間 - #{date.strftime('%m/%d')}",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "🕐 利用可能時間",
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
          contents: time_buttons,
          spacing: "sm"
        },
        footer: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "ご希望の時間をお選びください",
              size: "xs",
              color: "#666666",
              align: "center"
            }
          ]
        }
      }
    }
  
    send_reply(reply_token, message)
  end

  # 時間スロットが多い場合（11個以上）はページネーション
  def send_paginated_time_slots(user, reply_token, course, date_str, available_slots)
    date = Date.parse(date_str)
    
    # 午前（10:00-12:30）、午後（13:00-17:30）、夕方（18:00-20:00）に分割
    morning_slots = available_slots.select { |slot| slot[:start_time].hour < 13 }
    afternoon_slots = available_slots.select { |slot| slot[:start_time].hour >= 13 && slot[:start_time].hour < 18 }
    evening_slots = available_slots.select { |slot| slot[:start_time].hour >= 18 }
    
    periods = []
    periods << { name: "🌅 午前", slots: morning_slots, emoji: "🌅" } if morning_slots.any?
    periods << { name: "☀️ 午後", slots: afternoon_slots, emoji: "☀️" } if afternoon_slots.any?
    periods << { name: "🌆 夕方", slots: evening_slots, emoji: "🌆" } if evening_slots.any?
    
    if periods.length == 1
      # すべて同じ時間帯の場合は通常表示
      send_single_time_slots_message(user, reply_token, course, date_str, available_slots)
    else
      # 時間帯選択メッセージを送信
      send_time_period_selection(user, reply_token, course, date_str, periods)
    end
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

  # 時間帯選択メッセージ
  def send_time_period_selection(user, reply_token, course, date_str, periods)
    date = Date.parse(date_str)
    
    period_buttons = periods.map do |period|
      {
        type: "button",
        style: "primary",
        action: {
          type: "postback",
          label: "#{period[:emoji]} #{period[:name]} (#{period[:slots].length}件)",
          data: "select_time_period_#{course}_#{date_str}_#{period[:name].gsub(/[🌅☀️🌆\s]/, '')}"
        }
      }
    end

    message = {
      type: "flex",
      altText: "時間帯選択 - #{date.strftime('%m/%d')}",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "⏰ 時間帯選択",
              weight: "bold",
              size: "lg"
            },
            {
              type: "text",
              text: "#{date.strftime('%m/%d (%a)')} - #{course}",
              size: "sm",
              color: "#1976d2"
            },
            {
              type: "text",
              text: "利用可能: #{periods.sum { |p| p[:slots].length }}件",
              size: "xs",
              color: "#28a745",
              margin: "sm"
            }
          ]
        },
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "ご希望の時間帯をお選びください",
              wrap: true,
              margin: "md"
            }
          ] + period_buttons,
          spacing: "md"
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
                label: "🔙 日程選択に戻る",
                data: "book_#{course.gsub('分コース', 'min')}"
              }
            }
          ]
        }
      }
    }

    send_reply(reply_token, message)
  end

  # 時間帯が選択された場合の処理
  def handle_time_period_selection(user, reply_token, course, date_str, period_name)
    date = Date.parse(date_str)
    duration = get_duration_from_course(course)
    available_slots = get_available_time_slots(date, duration)
    
    # 選択された時間帯でフィルタリング
    filtered_slots = case period_name
    when '午前'
      available_slots.select { |slot| slot[:start_time].hour < 13 }
    when '午後'
      available_slots.select { |slot| slot[:start_time].hour >= 13 && slot[:start_time].hour < 18 }
    when '夕方'
      available_slots.select { |slot| slot[:start_time].hour >= 18 }
    else
      available_slots
    end
    
    if filtered_slots.empty?
      send_reply(reply_token, {
        type: "text",
        text: "申し訳ございません。選択された時間帯には空きがございません。"
      })
      return
    end
    
    # 最大12個まで表示
    display_slots = filtered_slots.first(12)
    
    time_buttons = display_slots.map do |slot|
      {
        type: "button",
        style: "secondary",
        action: {
          type: "postback",
          label: "#{slot[:start_time].strftime('%H:%M')} - #{slot[:end_time].strftime('%H:%M')}",
          data: "confirm_booking_#{course}_#{date_str}_#{slot[:start_time].strftime('%H:%M')}"
        }
      }
    end

    period_emoji = case period_name
    when '午前' then '🌅'
    when '午後' then '☀️'
    when '夕方' then '🌆'
    else '🕐'
    end

    message = {
      type: "flex",
      altText: "#{period_name}の利用可能時間",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "#{period_emoji} #{period_name}の空き時間",
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
          contents: time_buttons,
          spacing: "sm"
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
                label: "🔙 時間帯選択に戻る",
                data: "select_date_#{course}_#{date_str}"
              }
            }
          ]
        }
      }
    }

    send_reply(reply_token, message)
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

  # 🆕 Googleレビューメニュー送信
  def send_reviews_menu(reply_token)
    message = {
      type: "flex",
      altText: "Googleレビュー",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "⭐️ Googleレビュー",
              weight: "bold",
              size: "xl",
              color: "#4285F4"
            },
            {
              type: "text",
              text: "Googleでレビューを投稿してください",
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
              text: "📝 Googleレビュー投稿",
              weight: "bold",
              size: "md",
              margin: "md"
            },
            {
              type: "text",
              text: "ご利用いただいた感想やご意見をGoogleで共有してください。",
              size: "sm",
              color: "#666666",
              wrap: true,
              margin: "sm"
            },
            {
              type: "separator",
              margin: "md"
            },
            {
              type: "text",
              text: "📊 現在の評価",
              weight: "bold",
              size: "md",
              margin: "md"
            },
            {
              type: "text",
              text: "現在のGoogleレビューの評価をご確認いただけます。",
              size: "sm",
              color: "#666666",
              wrap: true,
              margin: "sm"
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
                label: "📝 Googleレビューを投稿",
                uri: "https://search.google.com/local/writereview?placeid=YOUR_PLACE_ID"
              }
            },
            {
              type: "button",
              style: "secondary",
              action: {
                type: "uri",
                label: "📊 Googleレビューを見る",
                uri: "https://www.google.com/maps/place/mobilis-stretch"
              }
            },
            {
              type: "button",
              style: "secondary",
              action: {
                type: "postback",
                label: "🔙 戻る",
                data: "reviews"
              }
            }
          ]
        }
      }
    }

    send_reply(reply_token, message)
  end

  # 🆕 最新情報メニュー送信
  def send_news_menu(reply_token)
    # 設定ファイルから最新情報を読み込み
    news_items = load_news_items

    message = {
      type: "flex",
      altText: "最新情報・お知らせ",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "📰 最新情報・お知らせ",
              weight: "bold",
              size: "xl",
              color: "#FF6B35"
            },
            {
              type: "text",
              text: "Mobilis Stretchからのお知らせ",
              size: "sm",
              color: "#666666"
            }
          ],
          paddingAll: "20px"
        },
        body: {
          type: "box",
          layout: "vertical",
          contents: news_items.map { |news|
            {
              type: "box",
              layout: "vertical",
              contents: [
                {
                  type: "box",
                  layout: "horizontal",
                  contents: [
                    {
                      type: "text",
                      text: news[:category],
                      size: "xs",
                      color: "#FFFFFF",
                      backgroundColor: get_category_color(news[:category]),
                      cornerRadius: "4px"
                    },
                    {
                      type: "text",
                      text: news[:date],
                      size: "xs",
                      color: "#999999",
                      align: "end"
                    }
                  ]
                },
                {
                  type: "text",
                  text: news[:title],
                  weight: "bold",
                  size: "md",
                  margin: "sm"
                },
                {
                  type: "text",
                  text: news[:content],
                  size: "sm",
                  color: "#333333",
                  wrap: true,
                  margin: "sm"
                }
              ],
              margin: "md"
            }
          }
        },
        footer: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "button",
              style: "secondary",
              action: {
                type: "uri",
                label: "🌐 ウェブサイトで詳しく見る",
                uri: "https://mobilis-stretch.com/news"
              }
            },
            {
              type: "button",
              style: "secondary",
              action: {
                type: "postback",
                label: "🔙 戻る",
                data: "news"
              }
            }
          ]
        }
      }
    }

    send_reply(reply_token, message)
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
    # 営業時間を統一（10:00-20:00、19:30最終受付想定）
    opening_time = Time.zone.parse("#{date} 10:00")
    closing_time = Time.zone.parse("#{date} 20:00")  # 20:00に統一
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

  # 最新情報を読み込むヘルパーメソッド
  def load_news_items
    # 設定ファイルから最新情報を読み込み
    news_file = Rails.root.join('config', 'news_items.yml')
    if File.exist?(news_file)
      YAML.load_file(news_file) || []
    else
      # デフォルトの最新情報
      [
        {
          category: "お知らせ",
          date: "2024/01/15",
          title: "新年のご挨拶",
          content: "本年もよろしくお願いいたします。"
        },
        {
          category: "営業時間",
          date: "2024/01/10",
          title: "営業時間変更のお知らせ",
          content: "1月15日より営業時間を10:00-20:00に変更いたします。"
        }
      ]
    end
  rescue => e
    Rails.logger.error "最新情報読み込みエラー: #{e.message}"
    []
  end

  # カテゴリ別の色を取得
  def get_category_color(category)
    case category
    when "お知らせ" then "#1976d2"
    when "営業時間" then "#ff9800"
    when "キャンペーン" then "#e91e63"
    when "メンテナンス" then "#9c27b0"
    else "#666666"
    end
  end

  def find_or_create_user_with_profile(user_id)
    user = User.find_by(line_user_id: user_id)
    if user.nil?
      # LINEからユーザー情報を取得
      profile = client.get_profile(user_id)
      user = User.create!(
        line_user_id: user_id,
        name: profile['displayName'],
        display_name: profile['displayName']
      )
    else
      # 既存ユーザーの情報を更新
      update_user_profile(user, user_id)
    end
    user
  end

  # 既存ユーザーのLINEプロフィール情報を更新
  def update_user_profile(user, user_id)
    begin
      Rails.logger.info "LINEプロフィール更新開始: #{user_id}"
      
      # LINE APIクライアントの確認
      unless client
        error_msg = "LINE APIクライアントの初期化に失敗しました"
        Rails.logger.error error_msg
        return false
      end
      
      # LINEからプロフィール情報を取得
      begin
        response = client.get_profile(user_id)
        Rails.logger.info "LINE APIレスポンス: #{response.inspect}"
        
        # レスポンスのステータスコードを確認
        unless response.is_a?(Net::HTTPSuccess)
          error_msg = "LINE API呼び出しに失敗しました: #{response.code} #{response.message}"
          Rails.logger.error error_msg
          return false
        end
        
        # レスポンスボディをJSONとして解析
        profile = JSON.parse(response.body)
        Rails.logger.info "LINEプロフィール取得成功: #{profile.inspect}"
      rescue => e
        error_msg = "LINE API呼び出しに失敗しました: #{e.class}: #{e.message}"
        Rails.logger.error error_msg
        return false
      end
      
      # プロフィール情報の検証
      unless profile && profile['displayName']
        error_msg = "LINEプロフィール情報が不正です: #{profile.inspect}"
        Rails.logger.error error_msg
        return false
      end
      
      # ユーザー情報を更新
      update_params = {
        display_name: profile['displayName']
      }
      
      Rails.logger.info "更新パラメータ: #{update_params.inspect}"
      
      # ユーザー情報の更新
      begin
        if user.update!(update_params)
          Rails.logger.info "LINEプロフィール更新完了: #{user_id} - #{profile['displayName']}"
          return true
        else
          Rails.logger.error "LINEプロフィール更新失敗: #{user.errors.full_messages}"
          return false
        end
      rescue => e
        error_msg = "ユーザー情報の更新に失敗しました: #{e.class}: #{e.message}"
        Rails.logger.error error_msg
        return false
      end
    rescue => e
      Rails.logger.error "LINEプロフィール更新エラー: #{user_id} - #{e.class}: #{e.message}"
      Rails.logger.error "バックトレース: #{e.backtrace.first(5).join("\n")}"
      return false
    end
  end
end

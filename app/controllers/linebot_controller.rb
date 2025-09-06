# app/controllers/linebot_controller.rb の改善版

class LinebotController < ApplicationController
  skip_before_action :verify_authenticity_token
  require 'line/bot'
  protect_from_forgery with: :null_session

  def callback
    Rails.logger.info "🔔 LINE webhook received"
    body = request.body.read
    Rails.logger.info "🔔 Request body length: #{body.length}"
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    Rails.logger.info "🔔 Signature present: #{signature.present?}"

    unless client.validate_signature(body, signature)
      Rails.logger.error "❌ Invalid signature"
      head :bad_request
      return
    end

    events = client.parse_events_from(body)
    Rails.logger.info "🔔 Parsed events: #{events.count} events"
    
    events.each do |event|
      Rails.logger.info "🔔 Processing event: #{event.class}"
      
      case event
      when Line::Bot::Event::Message
        Rails.logger.info "🔔 Message event type: #{event.type}"
        next unless event.type == Line::Bot::Event::MessageType::Text

        user_id = event['source']['userId']
        Rails.logger.info "📝 Text message from user: #{user_id}"
        user = find_or_create_user_with_profile(user_id)

        if user.notification_preference.nil?
          user.create_notification_preference!(enabled: true)
        end

        message_text = event.message['text']
        handle_text_message(user, message_text, event['replyToken'])

      when Line::Bot::Event::Postback
        Rails.logger.info "🔄 Postback event: #{event['postback']['data']}, user: #{event['source']['userId']}"

        user_id = event['source']['userId']
        user = find_or_create_user_with_profile(user_id)
        
        data = event['postback']['data']
        handle_postback_action(user, data, event['replyToken'])
      end
    end
  end

  # LINEフォロワーリストを取得
  def get_line_followers
    begin
      Rails.logger.info "🔄 Getting LINE followers..."
      
      # LINE APIクライアントの確認
      unless client
        error_msg = "LINE APIクライアントの初期化に失敗しました"
        Rails.logger.error error_msg
        return []
      end
      
      # LINEからフォロワーリストを取得（Messaging APIのエンドポイントを直接呼び出し）
      begin
        # LINE Messaging APIのフォロワーリスト取得エンドポイント
        uri = URI('https://api.line.me/v2/bot/followers/ids')
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = "Bearer #{ENV['LINE_CHANNEL_TOKEN']}"
        request['Content-Type'] = 'application/json'
        
        response = http.request(request)
        Rails.logger.info "LINE APIレスポンス: #{response.inspect}"
        
        # レスポンスのステータスコードを確認
        unless response.is_a?(Net::HTTPSuccess)
          error_msg = "LINE API呼び出しに失敗しました: #{response.code} #{response.message}"
          Rails.logger.error error_msg
          return []
        end
        
        # レスポンスボディをJSONとして解析
        followers_data = JSON.parse(response.body)
        Rails.logger.info "LINEフォロワー取得成功: #{followers_data.inspect}"
        
        # フォロワーリストを返す
        followers = followers_data['userIds'] || []
        Rails.logger.info "📊 Found #{followers.count} followers"
        
        # 各フォロワーの詳細情報を取得
        followers_with_details = []
        followers.each do |user_id|
          begin
            profile_response = client.get_profile(user_id)
            if profile_response.is_a?(Net::HTTPSuccess)
              profile = JSON.parse(profile_response.body)
              followers_with_details << {
                'userId' => user_id,
                'displayName' => profile['displayName'],
                'pictureUrl' => profile['pictureUrl'],
                'statusMessage' => profile['statusMessage']
              }
            else
              # プロフィール取得に失敗した場合は基本的な情報のみ
              followers_with_details << {
                'userId' => user_id,
                'displayName' => 'LINEユーザー',
                'pictureUrl' => nil,
                'statusMessage' => nil
              }
            end
          rescue => e
            Rails.logger.error "❌ Error getting profile for #{user_id}: #{e.message}"
            # エラーの場合も基本的な情報を追加
            followers_with_details << {
              'userId' => user_id,
              'displayName' => 'LINEユーザー',
              'pictureUrl' => nil,
              'statusMessage' => nil
            }
          end
        end
        
        Rails.logger.info "✅ Successfully retrieved #{followers_with_details.count} followers with details"
        return followers_with_details
        
      rescue => e
        error_msg = "LINE API呼び出しに失敗しました: #{e.class}: #{e.message}"
        Rails.logger.error error_msg
        return []
      end
      
    rescue => e
      Rails.logger.error "❌ LINE followers error: #{e.class}: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      return []
    end
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

  private

  # 多言語対応のヘルパーメソッド
  def get_message(user, key, **options)
    messages = {
      reservation_check_title: "📅 予約確認",
      reservation_check_title_en: "Reservation Check",
      reservation_check_subtitle: "今後の予約一覧",
      reservation_check_subtitle_en: "Upcoming Reservations",
      new_reservation: "新規予約",
      new_reservation_en: "New Reservation",
      cancel_reservation: "予約をキャンセル",
      cancel_reservation_en: "Cancel Reservation",
      return_to_check: "予約確認に戻る",
      return_to_check_en: "Back to Reservations",
      cancel_menu_title: "❌ 予約キャンセル",
      cancel_menu_title_en: "Cancel Reservation",
      cancel_menu_subtitle: "キャンセルしたい予約を選択",
      cancel_menu_subtitle_en: "Select reservation to cancel",
      cancel_warning: "⚠️ キャンセルした予約は復元できません",
      cancel_warning_en: "Cancelled reservations cannot be restored",
      no_reservations: "キャンセルできる予約がありません",
      no_reservations_en: "No reservations available for cancellation",
      no_upcoming_reservations: "現在、今後の予約はありません",
      no_upcoming_reservations_en: "Currently, no upcoming reservations",
      no_upcoming_reservations_sub: "新しい予約を取りたい場合は、下のボタンからお申し込みください",
      no_upcoming_reservations_sub_en: "To make a new reservation, please use the button below",
      confirmed: "✅ 確定",
      confirmed_en: "Confirmed",
      tentative: "⏳ 保留",
      tentative_en: "Pending",
      cancelled: "❌ キャンセル済み",
      cancelled_en: "Cancelled",
      cancellation_completed: "予約がキャンセルされました",
      cancellation_completed_en: "Reservation has been cancelled",
      location: "📍"
    }
    
    messages[key]
  end

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end
  end

  def handle_text_message(user, message_text, reply_token)
    # 🆕 デバッグログ：現在の状態を確認
    Rails.logger.info "🔍 handle_text_message called with:"
    Rails.logger.info "🔍 message_text: '#{message_text}'"
    Rails.logger.info "🔍 user.booking_state: '#{user.booking_state}'"
    Rails.logger.info "🔍 user.booking_location: '#{user.booking_location}'"
    Rails.logger.info "🔍 user.address: '#{user.address}'"
    
    # ユーザー情報収集中の場合は特別処理
    if user.booking_state == 'collecting_name'
      handle_name_input(user, message_text, reply_token)
      return
    elsif user.booking_state == 'collecting_phone'
      handle_phone_input(user, message_text, reply_token)
      return
    elsif user.booking_state == 'collecting_address'
      handle_address_input(user, message_text, reply_token)
      return
    end

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

    when /予約|booking|ご予約|予約したい|予約お願い/i
      send_booking_options(user, reply_token)

    when /40分|40分コース/i
      start_booking_flow(user, reply_token, "40分コース")

    when /60分|60分コース/i
      start_booking_flow(user, reply_token, "60分コース")

    when /80分|80分コース/i
      start_booking_flow(user, reply_token, "80分コース")

    when /今日|きょう|today/i
      send_today_availability(user, reply_token)

    when /明日|あした|tomorrow/i
      send_tomorrow_availability(user, reply_token)

    when /空き|空いてる|空き時間|available/i
      send_availability_info(user, reply_token)

    when /メニュー|menu/i
      send_main_menu(reply_token)

    when /ヘルプ|help|使い方/i
      send_help_message(reply_token)

    when /日程選択開始|日付選択開始|date selection/i
      # ユーザーのbooking_courseを確認
      if user.booking_course.present?
        course = user.booking_course
        Rails.logger.info "📅 Starting date selection via text for course: #{course}"
        start_date_selection(user, reply_token, course)
      else
        send_reply(reply_token, {
          type: "text",
          text: "申し訳ございません。コースが選択されていません。\nまずコースを選択してください。"
        })
      end

    else
      send_default_help(reply_token)
    end
  end

  def handle_postback_action(user, data, reply_token)
    Rails.logger.info "🔄 Postback action received: #{data}"
    Rails.logger.info "🔍 Postback data type: #{data.class}"
    Rails.logger.info "🔍 Postback data length: #{data.length}"
    
    case data
    when "check_tickets"
      Rails.logger.info "📋 Checking tickets for user: #{user.id} (#{user.name})"
      Rails.logger.info "📋 User line_user_id: #{user.line_user_id}"
      send_ticket_status(user, reply_token)

    when "usage_history"
      Rails.logger.info "📊 Showing usage history"
      send_usage_history(user, reply_token)

    when "booking"
      Rails.logger.info "📅 Showing booking options"
      send_booking_options(user, reply_token)

    when "news"
      Rails.logger.info "📰 Showing news menu"
      send_news_menu(reply_token)

    when "check_reservations"
      Rails.logger.info "📅 Showing reservation check for user: #{user.id} (#{user.name})"
      Rails.logger.info "📅 User has #{user.reservations.count} total reservations"
      Rails.logger.info "📅 User has #{user.reservations.where('start_time > ?', Time.current).count} upcoming reservations"
      send_reservation_check(user, reply_token)

    when "cancel_reservation_menu"
      Rails.logger.info "❌ Showing cancel reservation menu"
      send_cancel_reservation_menu(user, reply_token)

    when /^cancel_reservation_(\d+)$/
      reservation_id = $1.to_i
      Rails.logger.info "❌ Cancelling reservation ID: #{reservation_id} for user: #{user.id}"
      Rails.logger.info "🔍 Postback data: #{data}"
      Rails.logger.info "🔍 Matched regex pattern: cancel_reservation_#{reservation_id}"
      cancel_reservation(user, reservation_id, reply_token)

    when "reviews"
      Rails.logger.info "⭐ Showing reviews menu"
      send_reviews_menu(reply_token)

    when "check_tomorrow_availability"
      Rails.logger.info "📅 Checking tomorrow availability"
      send_tomorrow_availability(user, reply_token)

    when "start_info_collection"
      Rails.logger.info "📝 Starting info collection"
      start_info_collection(user, reply_token)

    when /^select_location_(.+)$/
      Rails.logger.info "🏠 Selecting location: #{$1}"
      handle_location_selection(user, reply_token, $1)

    when /^quick_book_60min_(.+)_(.+)$/
      Rails.logger.info "⚡ Quick booking 60min"
      date_str = $1
      time_str = $2
      create_booking(user, reply_token, "60分コース", date_str, time_str)

    when /^select_time_period_(.+)_(.+)_(.+)$/
      Rails.logger.info "⏰ Selecting time period"
      course = $1
      date = $2
      period = $3
      handle_time_period_selection(user, reply_token, course, date, period)

    when /^start_date_selection_(.+)$/
      Rails.logger.info "📅 Starting date selection for course: #{$1}"
      course_safe = $1
      # コース名を復元
      course = case course_safe
               when "60" then "60分コース"
               when "40" then "40分コース"
               when "80" then "80分コース"
               else "60分コース" # デフォルト
               end
      start_date_selection(user, reply_token, course)

    when /^select_date_(.+)_(.+)$/
      Rails.logger.info "📅 Selecting date"
      course = $1
      date = $2
      send_available_times(user, reply_token, course, date)
  
    when /^confirm_booking_(.+)_(.+)_(.+)$/
      Rails.logger.info "✅ Confirming booking"
      Rails.logger.info "✅ Course: #{$1}, Date: #{$2}, Time: #{$3}"
      course = $1
      date = $2
      time = $3
      create_booking(user, reply_token, course, date, time)  

    when /^book_(\d+)min$/
      Rails.logger.info "📅 Starting booking flow for #{$1}min course"
      course = "#{$1}分コース"
      start_booking_flow(user, reply_token, course)

    when /^cancel_booking_(\d+)$/
      Rails.logger.info "❌ Cancelling booking"
      reservation_id = $1.to_i
      handle_booking_cancellation(user, reply_token, reservation_id, "お客様都合によるキャンセル")

    when /^cancel_confirmed_booking_(\d+)$/
      Rails.logger.info "❌ Cancelling confirmed booking"
      reservation_id = $1.to_i
      handle_booking_cancellation(user, reply_token, reservation_id, "お客様都合によるキャンセル")

    when /^cancel_with_reason_(\d+)_(.+)$/
      Rails.logger.info "❌ Cancelling with reason"
      reservation_id = $1.to_i
      reason = $2
      handle_booking_cancellation(user, reply_token, reservation_id, reason)
    
    when /^urgent_cancel_(\d+)$/
      Rails.logger.info "🚨 Urgent cancellation"
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
      Rails.logger.error "⚠️ Unknown postback action: #{data}"
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

  # 🆕 今日の空き状況を表示
  def send_today_availability(user, reply_token)
    today = Date.current
    available_slots = get_available_time_slots(today, 60) # 60分コースを基準
    
    if available_slots.empty?
      message = {
        type: "flex",
        altText: "今日の空き状況",
        contents: {
          type: "bubble",
          header: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: "📅 今日の空き状況",
                weight: "bold",
                size: "lg"
              },
              {
                type: "text",
                text: today.strftime('%m/%d (%a)'),
                size: "sm",
                color: "#666666"
              }
            ]
          },
          body: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: "❌ 本日は予約可能な時間がございません",
                color: "#dc3545",
                weight: "bold"
              },
              {
                type: "text",
                text: "明日以降の予約をご検討ください",
                size: "sm",
                color: "#666666",
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
                  label: "明日の空きを確認",
                  data: "check_tomorrow_availability"
                }
              }
            ]
          }
        }
      }
    else
      time_buttons = available_slots.first(6).map do |slot|
        {
          type: "button",
          style: "secondary",
          action: {
            type: "postback",
            label: slot[:start_time].strftime('%H:%M'),
            data: "quick_book_60min_#{today.strftime('%Y-%m-%d')}_#{slot[:start_time].strftime('%H:%M')}"
          }
        }
      end

      message = {
        type: "flex",
        altText: "今日の空き状況",
        contents: {
          type: "bubble",
          header: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: "📅 今日の空き状況",
                weight: "bold",
                size: "lg"
              },
              {
                type: "text",
                text: today.strftime('%m/%d (%a)'),
                size: "sm",
                color: "#666666"
              }
            ]
          },
          body: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: "✅ 以下の時間が予約可能です",
                color: "#28a745",
                weight: "bold"
              },
              {
                type: "text",
                text: "60分コースで予約可能な時間",
                size: "sm",
                color: "#666666",
                margin: "md"
              }
            ]
          },
          footer: {
            type: "box",
            layout: "vertical",
            contents: time_buttons
          }
        }
      }
    end

    send_reply(reply_token, message)
  end

  # 🆕 明日の空き状況を表示
  def send_tomorrow_availability(user, reply_token)
    tomorrow = Date.current + 1.day
    available_slots = get_available_time_slots(tomorrow, 60) # 60分コースを基準
    
    if available_slots.empty?
      message = {
        type: "flex",
        altText: "明日の空き状況",
        contents: {
          type: "bubble",
          header: {
            type: "box",
            layout: "vertical",
            contents: [
              {
        type: "text",
                text: "📅 明日の空き状況",
                weight: "bold",
                size: "lg"
              },
              {
                type: "text",
                text: tomorrow.strftime('%m/%d (%a)'),
                size: "sm",
                color: "#666666"
              }
            ]
          },
          body: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: "❌ 明日は予約可能な時間がございません",
                color: "#dc3545",
                weight: "bold"
              },
              {
                type: "text",
                text: "他の日付をご検討ください",
                size: "sm",
                color: "#666666",
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
                  label: "他の日付を確認",
                  data: "booking"
                }
              }
            ]
          }
        }
      }
    else
      time_buttons = available_slots.first(6).map do |slot|
        {
          type: "button",
          style: "secondary",
          action: {
            type: "postback",
            label: slot[:start_time].strftime('%H:%M'),
            data: "quick_book_60min_#{tomorrow.strftime('%Y-%m-%d')}_#{slot[:start_time].strftime('%H:%M')}"
          }
        }
    end

    message = {
      type: "flex",
        altText: "明日の空き状況",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
                text: "📅 明日の空き状況",
              weight: "bold",
              size: "lg"
            },
            {
              type: "text",
                text: tomorrow.strftime('%m/%d (%a)'),
              size: "sm",
                color: "#666666"
            }
          ]
        },
        body: {
          type: "box",
          layout: "vertical",
            contents: [
              {
                type: "text",
                text: "✅ 以下の時間が予約可能です",
                color: "#28a745",
                weight: "bold"
              },
              {
                type: "text",
                text: "60分コースで予約可能な時間",
                size: "sm",
                color: "#666666",
                margin: "md"
              }
            ]
          },
          footer: {
            type: "box",
            layout: "vertical",
            contents: time_buttons
          }
        }
      }
    end

    send_reply(reply_token, message)
  end

  # 🆕 空き状況の概要を表示
  def send_availability_info(user, reply_token)
    today = Date.current
    tomorrow = today + 1.day
    
    today_slots = get_available_time_slots(today, 60)
    tomorrow_slots = get_available_time_slots(tomorrow, 60)
    
    message = {
      type: "flex",
      altText: "空き状況の概要",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "📅 空き状況の概要",
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
              text: "今日 (#{today.strftime('%m/%d')})",
              weight: "bold",
              size: "sm"
            },
            {
              type: "text",
              text: today_slots.empty? ? "❌ 予約不可" : "✅ #{today_slots.count}枠空き",
              size: "sm",
              color: today_slots.empty? ? "#dc3545" : "#28a745",
              margin: "sm"
            },
            {
              type: "text",
              text: "明日 (#{tomorrow.strftime('%m/%d')})",
              weight: "bold",
              size: "sm",
              margin: "md"
            },
            {
              type: "text",
              text: tomorrow_slots.empty? ? "❌ 予約不可" : "✅ #{tomorrow_slots.count}枠空き",
              size: "sm",
              color: tomorrow_slots.empty? ? "#dc3545" : "#28a745",
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
                type: "postback",
                label: "詳細を確認",
                data: "booking"
              }
            }
          ]
        }
      }
    }

    send_reply(reply_token, message)
  end

  # 🆕 メインメニューを表示
  def send_main_menu(reply_token)
    message = {
      type: "flex",
      altText: "メインメニュー",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "🏠 メインメニュー",
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
              type: "button",
              style: "primary",
              action: {
                type: "postback",
                label: "📅 予約する",
                data: "booking"
              }
            },
            {
              type: "button",
              style: "secondary",
              action: {
                type: "postback",
                label: "📋 チケット確認",
                data: "check_tickets"
              }
            },
            {
              type: "button",
              style: "secondary",
              action: {
                type: "postback",
                label: "📊 利用履歴",
                data: "usage_history"
              }
            },
            {
              type: "button",
              style: "secondary",
              action: {
                type: "postback",
                label: "📰 最新情報",
                data: "news"
              }
            }
          ],
          spacing: "sm"
        }
      }
    }

    send_reply(reply_token, message)
  end

  # 🆕 ヘルプメッセージを表示
  def send_help_message(reply_token)
    message = {
      type: "flex",
      altText: "使い方ガイド",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "❓ 使い方ガイド",
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
              text: "📝 よく使うコマンド",
              weight: "bold",
              size: "sm"
            },
            {
              type: "text",
              text: "• 予約 → 予約メニュー\n• 今日 → 今日の空き確認\n• 明日 → 明日の空き確認\n• 空き → 空き状況確認\n• メニュー → メインメニュー",
              size: "sm",
              color: "#666666",
              margin: "sm",
              wrap: true
            },
            {
              type: "text",
              text: "📱 リッチメニュー",
              weight: "bold",
              size: "sm",
              margin: "md"
            },
            {
              type: "text",
              text: "画面下部の「メニューを開く」からも各種機能をご利用いただけます。",
              size: "sm",
              color: "#666666",
              margin: "sm",
              wrap: true
            }
          ]
        }
      }
    }

    send_reply(reply_token, message)
  end
  def start_booking_flow(user, reply_token, course)
    Rails.logger.info "🔄 start_booking_flow called for user #{user.id}, course: #{course}"
    
    # コース情報を保存して場所選択画面を表示
    user.update(booking_course: course)
    send_location_selection(user, reply_token)
  end

  # 🆕 日付選択画面を表示

  # 🆕 ユーザー情報入力を促す
  def send_user_info_request(user, reply_token, course)
    Rails.logger.info "📝 send_user_info_request called for user #{user.id}"
    Rails.logger.info "📝 User current info - name: '#{user.name}', phone: '#{user.phone_number}', address: '#{user.address}'"
    
    missing_info = []
    missing_info << "お名前" unless user.name.present?
    missing_info << "お電話番号" unless user.phone_number.present?
    missing_info << "ご住所" unless user.address.present?
    
    Rails.logger.info "📝 Missing info: #{missing_info.join(', ')}"
    
    # 保存するコース情報
    user.update(booking_course: course)

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
              color: "#1976d2"
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
              text: "LINEチャットで順番に入力していきましょう",
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
                type: "postback",
                label: "情報入力開始",
                data: "start_info_collection"
              }
            }
          ]
        }
      }
    }

    send_reply(reply_token, message)
  end

  # 🆕 名前入力の処理
  def handle_name_input(user, message_text, reply_token)
    user.update(name: message_text, booking_state: 'collecting_phone')
    
    send_reply(reply_token, {
      type: "text",
      text: "ありがとうございます！\n\n次にお電話番号を教えてください。\n例: 090-1234-5678"
    })
  end

  # 🆕 電話番号入力の処理
  def handle_phone_input(user, message_text, reply_token)
    # 電話番号の簡易バリデーション
    phone = message_text.gsub(/[^\d]/, '')
    if phone.length >= 10
      user.update(phone_number: message_text, booking_state: 'collecting_address')
      
      send_reply(reply_token, {
        type: "text",
        text: "ありがとうございます！\n\n最後にご住所を教えてください。\n例: 東京都渋谷区○○1-2-3"
      })
    else
      send_reply(reply_token, {
        type: "text",
        text: "電話番号の形式が正しくありません。\n090-1234-5678 のような形式で入力してください。"
      })
    end
  end

  # 🆕 住所入力の処理
  def handle_address_input(user, message_text, reply_token)
    Rails.logger.info "🔍 handle_address_input called with:"
    Rails.logger.info "🔍 message_text: '#{message_text}'"
    Rails.logger.info "🔍 user.booking_location: '#{user.booking_location}'"
    Rails.logger.info "🔍 user.address: '#{user.address}'"
    
    # 🆕 「日程選択開始」などの特殊なメッセージは住所として保存しない
    if message_text.match?(/日程選択開始|日付選択開始|date selection/i)
      Rails.logger.info "🔍 Special message detected, not saving as address"
      send_reply(reply_token, {
        type: "text",
        text: "申し訳ございません。住所を入力してください。\n\n例: 東京都渋谷区○○1-2-3"
      })
      return
    end
    
    # 場所情報を含めた住所を保存
    location_type = user.booking_location || 'unknown'
    
    case location_type
    when 'home'
      # 自宅の場合は住所のみを保存（プレフィックスなし）
      user.update(address: message_text, booking_state: nil, booking_location: nil)
      location_text = "自宅: #{message_text}"
    when 'other'
      # 別の場所の場合は住所を更新せず、予約時に直接使用
      user.update(booking_state: nil, booking_location: 'other')
      # 別の場所の住所を一時的に保存（セッション変数として）
      Rails.cache.write("other_location_address_#{user.id}", message_text, expires_in: 1.hour)
      location_text = "別の場所: #{message_text}"
    when 'rental'
      # レンタルスペースの場合は住所を更新しない
      location_text = "レンタルスペース: #{message_text}"
      user.update(booking_state: nil, booking_location: nil)
    else
      location_text = message_text
      user.update(address: location_text, booking_state: nil, booking_location: nil)
    end
    
    Rails.logger.info "🔍 Address saved: '#{location_text}'"
    
    # 予約フローを再開
    course = user.booking_course
    user.update(booking_course: nil)
    
    send_reply(reply_token, {
      type: "text",
      text: "ありがとうございます！\n\n住所の入力が完了しました。\n予約フローを開始します。"
    })
    
    # 少し待ってから日付選択を開始（push_message使用）
    sleep(1)
    start_date_selection_with_push(user, course)
  end

  # 🆕 情報収集開始
  def start_info_collection(user, reply_token)
    Rails.logger.info "📝 start_info_collection called for user #{user.id}"
    Rails.logger.info "📝 User current info - name: '#{user.name}', phone: '#{user.phone_number}', address: '#{user.address}'"
    Rails.logger.info "📝 User booking_state: #{user.booking_state}"
    
    # 不足している情報を確認
    if !user.name.present?
      user.update(booking_state: 'collecting_name')
      send_reply(reply_token, {
        type: "text",
        text: "まず、お名前を教えてください。\n\nフルネームで入力してください。\n例: 田中太郎"
      })
    elsif !user.phone_number.present?
      user.update(booking_state: 'collecting_phone')
      send_reply(reply_token, {
        type: "text",
        text: "次にお電話番号を教えてください。\n例: 090-1234-5678"
      })
    elsif !user.address.present?
      # 場所選択画面を表示
      send_location_selection(user, reply_token)
    else
      # すべての情報が揃っている場合は予約フローを再開
      course = user.booking_course
      user.update(booking_course: nil, booking_state: nil)
      send_reply(reply_token, {
        type: "text",
        text: "情報の入力が完了しました。\n予約フローを再開します。"
      })
      sleep(1)
      start_booking_flow(user, reply_token, course)
    end
  end

  # 🆕 場所選択画面を送信
  def send_location_selection(user, reply_token)
    user.update(booking_state: 'selecting_location')
    
    message = {
      type: "flex",
      altText: "ストレッチ場所の選択",
      contents: {
        type: "bubble",
        header: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "🏠 ストレッチ場所",
              weight: "bold",
              size: "lg",
              color: "#1976d2"
            }
          ]
        },
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "ストレッチを受ける場所を選択してください：",
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
              style: "primary",
              action: {
                type: "postback",
                label: "🏠 自宅",
                data: "select_location_home"
              }
            },
            {
              type: "button",
              style: "secondary",
              action: {
                type: "postback",
                label: "📍 別の場所",
                data: "select_location_other"
              },
              margin: "sm"
            },
            {
              type: "button",
              style: "secondary",
              action: {
                type: "postback",
                label: "🏢 レンタルスペース",
                data: "select_location_rental"
              },
              margin: "sm"
            }
          ]
        }
      }
    }
    
    send_reply(reply_token, message)
  end

  # 🆕 場所選択の処理
  def handle_location_selection(user, reply_token, location_type)
    case location_type
    when 'home'
      # 自宅の場合：登録済みの住所を使用
      if user.address.present?
        # 登録済みの住所がある場合は直接予約フローに進む
        course = user.booking_course
        # 住所情報を保持し、booking_locationをクリア
        user.update(booking_location: 'home', booking_state: nil)
        
        # コース名をURLセーフな形式に変換
        course_safe = course.gsub(/[^\w\s]/, '').gsub(/\s+/, '_')
        
        # 日程選択を直接開始（push_message使用）
        sleep(1)
        start_date_selection_with_push(user, course)
      else
        # 登録済みの住所がない場合は住所入力を促す
        user.update(booking_state: 'collecting_address', booking_location: 'home')
        send_reply(reply_token, {
          type: "text",
          text: "ご自宅の住所を教えてください。\n\n例: 東京都渋谷区○○1-2-3"
        })
      end
    when 'other'
      # 別の場所の場合：住所入力
      user.update(booking_state: 'collecting_address', booking_location: 'other')
      send_reply(reply_token, {
        type: "text",
        text: "ストレッチを受ける場所の住所を教えてください。\n\n例: 東京都渋谷区○○1-2-3"
      })
    when 'rental'
      # レンタルスペースの場合：こちらから連絡
      course = user.booking_course
      # レンタルスペースとして設定
      user.update(booking_location: 'rental', booking_state: nil)
      
      # コース名をURLセーフな形式に変換
      course_safe = course.gsub(/[^\w\s]/, '').gsub(/\s+/, '_')
      
      # 日程選択を直接開始（push_message使用）
      sleep(1)
      start_date_selection_with_push(user, course)
    else
      send_reply(reply_token, {
        type: "text",
        text: "申し訳ございません。場所の選択に問題が発生しました。もう一度お試しください。"
      })
    end
  end

  # 🆕 日付選択画面を表示
  def start_date_selection(user, reply_token, course)
    Rails.logger.info "📅 start_date_selection called for user #{user.id}, course: #{course}"
    
    # 利用可能な日付を表示
    available_dates = get_available_dates(7) # 今日から7日間
    Rails.logger.info "📅 Found #{available_dates.count} available dates: #{available_dates.map(&:strftime).join(', ')}"
    
    if available_dates.empty?
      Rails.logger.info "❌ No available dates found"
      send_reply(reply_token, {
        type: "text",
        text: "申し訳ございません。現在予約可能な日程がございません。\nお電話でお問い合わせください: 03-1234-5678"
      })
      return
    end
    
    Rails.logger.info "📝 Creating date selection message"
    
    # コース名をURLセーフな形式に変換
    course_safe = course.gsub(/[^\w\s]/, '').gsub(/\s+/, '_')
    
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
            Rails.logger.info "📝 Creating date button for #{date.strftime('%Y-%m-%d')}"
            {
              type: "button",
              style: "secondary",
              action: {
                type: "postback",
                label: date.strftime('%m/%d (%a)'),
                data: "select_date_#{course_safe}_#{date.strftime('%Y-%m-%d')}"
              }
            }
          },
          spacing: "sm"
        }
      }
    }
    
    Rails.logger.info "📤 Sending date selection message"
    begin
      # まずシンプルなテキストメッセージでテスト
      send_reply(reply_token, {
        type: "text",
        text: "日程選択画面を表示します。\n\n利用可能な日程：\n#{available_dates.map { |date| "• #{date.strftime('%m/%d (%a)')}" }.join('\n')}"
      })
      Rails.logger.info "✅ Date selection message sent successfully"
    rescue => e
      Rails.logger.error "❌ Error sending date selection message: #{e.message}"
      Rails.logger.error "❌ Error backtrace: #{e.backtrace.first(5).join('\n')}"
      # フォールバック：シンプルなテキストメッセージを送信
      send_reply(reply_token, {
        type: "text",
        text: "日程選択画面の表示に問題が発生しました。\n\n利用可能な日程：\n#{available_dates.map { |date| "• #{date.strftime('%m/%d (%a)')}" }.join('\n')}\n\n希望の日程をお電話でお申し込みください: 03-1234-5678"
      })
    end
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
    Rails.logger.info "📝 send_single_time_slots_message called for course: #{course}, date: #{date_str}"
    Rails.logger.info "📝 Available slots count: #{available_slots.count}"
    
    time_buttons = available_slots.map do |slot|
      postback_data = "confirm_booking_#{course}_#{date_str}_#{slot[:start_time].strftime('%H:%M')}"
      Rails.logger.info "📝 Creating button with postback data: #{postback_data}"
      
      {
        type: "button",
        style: "secondary",
        action: {
          type: "postback",
          label: "#{slot[:start_time].strftime('%H:%M')} - #{slot[:end_time].strftime('%H:%M')}",
          data: postback_data
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
    Rails.logger.info "📝 create_booking called for user #{user.id}"
    Rails.logger.info "📝 Course: #{course}, Date: #{date_str}, Time: #{time_str}"
    
    begin
      date = Date.parse(date_str)
      start_time = Time.zone.parse("#{date} #{time_str}")
      duration = get_duration_from_course(course)
      end_time = start_time + duration.minutes

      # 重複チェック（Reservationモデルのno_time_overlapと同じロジック）
      overlapping = Reservation.active
        .where.not(id: nil) # 新規作成時はidがnil
        .select do |other|
          # 各予約のインターバル時間を取得（デフォルト10分）
          other_interval = other.respond_to?(:effective_interval_minutes) ? other.effective_interval_minutes : 10
          other_end_with_interval = other.end_time + other_interval.minutes
          
          # 現在の予約のインターバル時間を取得（デフォルト10分）
          current_interval = 10 # デフォルト値
          current_end_with_interval = end_time + current_interval.minutes
          
          # 重複判定（インターバル時間も含む）
          overlap = start_time < other_end_with_interval && current_end_with_interval > other.start_time
          
          Rails.logger.info "🔍 Checking overlap with reservation #{other.id}: #{other.start_time.strftime('%H:%M')} - #{other_end_with_interval.strftime('%H:%M')}"
          Rails.logger.info "🔍 Current reservation: #{start_time.strftime('%H:%M')} - #{current_end_with_interval.strftime('%H:%M')}"
          Rails.logger.info "🔍 Overlap: #{overlap}"
          
          overlap
        end

      if overlapping.any?
        overlapping_reservation = overlapping.first
        other_interval = overlapping_reservation.respond_to?(:effective_interval_minutes) ? overlapping_reservation.effective_interval_minutes : 10
        other_end_with_interval = overlapping_reservation.end_time + other_interval.minutes
        
        Rails.logger.info "❌ Overlap detected: #{overlapping_reservation.start_time.strftime('%H:%M')} - #{other_end_with_interval.strftime('%H:%M')}"
        
        send_reply(reply_token, {
          type: "text",
          text: "申し訳ございません。選択された時間は既に予約が入っております。\n別の時間をお選びください。"
        })
        return
      end

      # メモにLINE予約とストレッチ場所の情報を追加
      note_parts = ["LINEからの予約"]
      
      # ストレッチ場所の情報を追加
      if user.booking_location.present?
        case user.booking_location
        when 'home'
          note_parts << "ストレッチ場所: 自宅"
        when 'other'
          # 別の場所の場合は住所も含める
          other_address = Rails.cache.read("other_location_address_#{user.id}")
          if other_address.present?
            note_parts << "ストレッチ場所: 別の場所 (#{other_address})"
          else
            note_parts << "ストレッチ場所: 別の場所"
          end
        when 'rental'
          note_parts << "ストレッチ場所: レンタルスペース"
        end
      elsif user.address.present?
        # 住所から場所タイプを推測
        if user.address.include?("自宅:")
          note_parts << "ストレッチ場所: 自宅"
        elsif user.address.include?("別の場所:")
          # 別の場所の場合は住所も含める
          address_part = user.address.gsub("別の場所: ", "")
          note_parts << "ストレッチ場所: 別の場所 (#{address_part})"
        elsif user.address.include?("レンタルスペース:")
          note_parts << "ストレッチ場所: レンタルスペース"
        else
          note_parts << "ストレッチ場所: 住所指定 (#{user.address})"
        end
      else
        note_parts << "ストレッチ場所: 未設定"
      end
      
      reservation = Reservation.new(
        name: user.name,
        start_time: start_time,
        end_time: end_time,
        course: course,
        status: :tentative, # 仮予約
        user: user,
        note: note_parts.join(" | ")
      )
      
      # バリデーションをスキップして保存
      reservation.skip_overlap_validation = true
      reservation.save!

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
              create_info_row("ご住所", get_display_address(user)),
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

      # 🆕 デバッグログ：住所情報を確認
      Rails.logger.info "🔍 予約作成時の住所情報確認:"
      Rails.logger.info "🔍 user.address: '#{user.address}'"
      Rails.logger.info "🔍 user.booking_location: '#{user.booking_location}'"
      Rails.logger.info "🔍 user.booking_state: '#{user.booking_state}'"

      # 🆕 別の場所の場合は元の住所に戻す
      if user.address.present? && user.address.include?("別の場所:")
        # 元の住所を復元（別の場所の住所を削除）
        original_address = user.address.gsub("別の場所: ", "").strip
        # 元の住所が自宅の形式でない場合は、自宅として保存
        if !original_address.include?("自宅:")
          user.update(address: "自宅: #{original_address}")
        end
        Rails.logger.info "🔍 住所を元に戻しました: '#{user.address}'"
      end

      # 🆕 別の場所の住所をクリア
      if user.respond_to?(:other_location_address) && user.other_location_address.present?
        user.update(other_location_address: nil, booking_location: nil)
        Rails.logger.info "🔍 別の場所の住所をクリアしました"
      end

      # 🆕 キャッシュから別の場所の住所をクリア
      Rails.cache.delete("other_location_address_#{user.id}")
      Rails.logger.info "🔍 キャッシュから別の場所の住所をクリアしました"

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
    Rails.logger.info "🎫 send_ticket_status called for user: #{user.id} (#{user.name})"
    tickets = user.tickets.where("remaining_count > 0 AND expiry_date >= ?", Time.zone.today)
    Rails.logger.info "🎫 Found #{tickets.count} active tickets"
    
    if tickets.any?
      bubbles = tickets.map do |t|
        expiry_soon = t.expiry_date <= Time.zone.today + 30.days
        low_remaining = t.remaining_count <= 2
  
        {
          type: "bubble",
          header: {
            type: "box",
            layout: "vertical",
            contents: [
          {
            type: "text",
                text: "🎫 チケット情報",
            weight: "bold",
            size: "lg",
                color: "#1976d2",
                align: "center"
          },
          {
            type: "text",
                text: "Ticket Information",
                size: "sm",
                color: "#999999",
                align: "center",
                margin: "xs"
              }
            ],
            paddingAll: "15px",
            paddingTop: "20px",
            paddingBottom: "10px"
          },
          body: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: t.title.present? ? t.title : "チケット",
                weight: "bold",
            size: "md",
                wrap: true,
                align: "center"
              },
          {
            type: "text",
                text: t.ticket_template.present? ? t.ticket_template.name : "コース未設定",
            size: "sm",
                color: "#666666",
            margin: "sm",
                align: "center"
              },
              {
                type: "separator",
                margin: "md"
              },
              {
                type: "box",
                layout: "horizontal",
                contents: [
                  {
                    type: "box",
                    layout: "vertical",
                    contents: [
                      {
                        type: "text",
                        text: "残り回数",
                        size: "sm",
                        color: "#666666",
                        flex: 0
                      },
                      {
                        type: "text",
                        text: "Remaining Count",
                        size: "xs",
                        color: "#999999",
                        flex: 0
                      }
                    ],
                    flex: 0
                  },
                  {
                    type: "text",
                    text: "　　　",
                    size: "sm",
                    flex: 0
                  },
                  {
                    type: "text",
                    text: "#{t.remaining_count}回",
                    weight: "bold",
                    size: "sm",
                    color: low_remaining ? "#FFA500" : "#1976d2",
                    flex: 0,
                    align: "end"
                  }
                ],
                margin: "md"
              },
              {
                type: "box",
                layout: "horizontal",
                contents: [
                  {
            type: "box",
            layout: "vertical",
                    contents: [
                      {
                        type: "text",
                        text: "有効期限",
                        size: "sm",
                        color: "#666666",
                        flex: 0
                      },
                      {
                        type: "text",
                        text: "Expiry Date",
                        size: "xs",
                        color: "#999999",
                        flex: 0
                      }
                    ],
                    flex: 0
                  },
                  {
                    type: "text",
                    text: "　　　　",
                    size: "sm",
                    flex: 0
                  },
                  {
                    type: "text",
                    text: t.expiry_date.strftime('%Y/%m/%d'),
                    size: "sm",
                    color: expiry_soon ? "#FF5555" : "#888888",
                    flex: 0,
                    align: "end"
                  }
                ],
                margin: "md"
              }
            ],
            paddingAll: "20px"
          }
        }
      end
  
      send_reply(reply_token, { 
        type: "flex",
        altText: "使用可能な回数券一覧",
        contents: {
          type: "carousel",
          contents: bubbles
        }
      })
    else
      send_reply(reply_token, {
        type: "flex",
        altText: "チケット情報",
        contents: {
          type: "bubble",
          header: {
            type: "box",
            layout: "vertical",
            contents: [
              {
        type: "text",
                text: "🎫 チケット情報",
                weight: "bold",
                size: "lg",
                color: "#1976d2",
                align: "center"
              },
              {
                type: "text",
                text: "Ticket Information",
                size: "sm",
                color: "#999999",
                align: "center",
                margin: "xs"
              }
            ],
            paddingAll: "15px",
            paddingTop: "20px",
            paddingBottom: "10px"
          },
          body: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: "使用可能な回数券がありません",
                size: "md",
                color: "#666666",
                align: "center",
                margin: "lg"
              },
              {
                type: "text",
                text: "No available tickets",
                size: "sm",
                color: "#999999",
                align: "center",
                margin: "xs"
              }
            ],
            paddingAll: "20px"
          }
        }
      })
    end
  end

  def send_usage_history(user, reply_token)
    Rails.logger.info "🕓 send_usage_history called for user: #{user.id} (#{user.name})"
    usages = user.ticket_usages.order(used_at: :desc).limit(12)
    Rails.logger.info "🕓 Found #{usages.count} usage records"
  
    if usages.any?
      # リスト形式で12件表示
      list_items = usages.map.with_index(1) do |usage, index|
        ticket_title = usage.ticket.title.present? ? usage.ticket.title : "回数券"
        course_name = usage.ticket.ticket_template.present? ? usage.ticket.ticket_template.name : "コース未設定"
        date = usage.used_at.strftime('%m/%d')
        
        {
          type: "box",
          layout: "horizontal",
          contents: [
            {
              type: "text",
              text: "#{index}.",
              size: "sm",
              color: "#666666",
              flex: 0,
              margin: "sm"
            },
            {
              type: "box",
              layout: "vertical",
              contents: [
                {
                  type: "text",
                  text: course_name,
                  weight: "bold",
                  size: "sm",
                  wrap: true
                }
              ],
              flex: 1,
              margin: "sm"
            },
            {
              type: "box",
              layout: "vertical",
              contents: [
                {
                  type: "text",
                  text: date,
                  size: "sm",
                  color: "#1976d2",
                  align: "end"
                }
              ],
              flex: 0,
              margin: "sm"
            }
          ],
          margin: "xs",
          paddingAll: "sm",
          backgroundColor: index.odd? ? "#f8f9fa" : "#ffffff"
        }
      end

      send_reply(reply_token, {
        type: "flex",
        altText: "使用履歴一覧（12件）",
        contents: {
          type: "bubble",
          header: {
            type: "box",
            layout: "vertical",
            contents: [
              {
        type: "text",
                text: "🕓 使用履歴（直近12回）",
                weight: "bold",
                size: "lg",
                color: "#1976d2",
                align: "center"
              },
              {
                type: "text",
                text: "Usage History (Last 12 times)",
                size: "sm",
                color: "#999999",
                align: "center",
                margin: "xs"
              }
            ],
            paddingAll: "15px",
            paddingTop: "20px",
            paddingBottom: "10px"
          },
          body: {
            type: "box",
            layout: "vertical",
            contents: list_items,
            paddingAll: "10px"
          }
        }
      })
    else
      send_reply(reply_token, {
        type: "flex",
        altText: "使用履歴",
        contents: {
          type: "bubble",
          header: {
            type: "box",
            layout: "vertical",
            contents: [
              {
        type: "text",
                text: "🕓 使用履歴",
                weight: "bold",
                size: "lg",
                color: "#1976d2",
                align: "center"
              },
              {
                type: "text",
                text: "Usage History",
                size: "sm",
                color: "#999999",
                align: "center",
                margin: "xs"
              }
            ],
            paddingAll: "15px",
            paddingTop: "20px",
            paddingBottom: "10px"
          },
          body: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: "使用履歴が見つかりません",
                size: "md",
                color: "#666666",
                align: "center",
                margin: "lg"
              },
              {
                type: "text",
                text: "まだチケットを使用していないか、\n履歴がありません。",
                size: "sm",
                color: "#888888",
                align: "center",
                wrap: true,
                margin: "md"
              },
              {
                type: "text",
                text: "No ticket usage history found.",
                size: "xs",
                color: "#999999",
                align: "center",
                wrap: true,
                margin: "xs"
              }
            ],
            paddingAll: "20px"
          }
        }
      })
    end
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
    # GoogleビジネスプロフィールのURLを取得
    google_review_url = get_google_review_url
    google_business_url = get_google_business_url
    
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
              color: "#4285F4",
              align: "center"
            }
          ],
          paddingAll: "10px",
          paddingTop: "20px",
          paddingBottom: "5px"
        },
        body: {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "ご利用いただいた感想やご意見を\nGoogleで共有してください。",
              size: "sm",
              color: "#666666",
              wrap: true,
              margin: "md",
              align: "center"
            },
            {
              type: "separator",
              margin: "lg"
            },
            {
              type: "text",
              text: "🏢 Mobilis Stretch",
              weight: "bold",
              size: "md",
              margin: "md",
              align: "center"
            },
            {
              type: "text",
              text: "出張ストレッチサービス",
              size: "sm",
              color: "#666666",
              wrap: true,
              margin: "sm",
              align: "center"
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
                label: "📝 レビューを投稿",
                uri: google_review_url
              },
              margin: "sm"
            },
            {
              type: "button",
              style: "secondary",
              action: {
                type: "uri",
                label: "📊 レビューを見る",
                uri: google_business_url
              },
              margin: "sm"
            },
            {
              type: "button",
              style: "secondary",
              action: {
                type: "postback",
                label: "🔙 戻る",
                data: "reviews"
              },
              margin: "sm"
              }
          ],
          paddingAll: "20px"
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
    Rails.logger.info "📤 send_reply called with token: #{reply_token}"
    Rails.logger.info "📤 Message type: #{message[:type]}"
    
    begin
      Rails.logger.info "📤 About to call LINE API with message: #{message.inspect}"
      response = client.reply_message(reply_token, message)
      Rails.logger.info "📤 LINE API response code: #{response.code}"
      
      # エンコーディングエラーを避けるため、レスポンスボディを安全にログ出力
      begin
        response_body = response.body.force_encoding('UTF-8')
        Rails.logger.info "📤 LINE API response body: #{response_body}"
      rescue => encoding_error
        Rails.logger.info "📤 LINE API response body: [encoding error: #{encoding_error.message}]"
      end
      
      if response.code != '200'
        Rails.logger.error "❌ LINE API error: #{response_body}"
      else
        Rails.logger.info "✅ LINE API call successful"
      end
    rescue => e
      Rails.logger.error "❌ send_reply error: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.first(5).join("\n")}"
    end
  end

  # 🆕 push_messageメソッド
  def push_message(user_id, message)
    Rails.logger.info "📤 push_message called for user: #{user_id}"
    Rails.logger.info "📤 Message type: #{message[:type]}"
    
    begin
      Rails.logger.info "📤 About to call LINE API with push message: #{message.inspect}"
      response = client.push_message(user_id, message)
      Rails.logger.info "📤 LINE API response code: #{response.code}"
      Rails.logger.info "📤 LINE API response body: #{response.body}"
      
      if response.code != '200'
        Rails.logger.error "❌ LINE API error: #{response.body}"
      else
        Rails.logger.info "✅ LINE API push call successful"
      end
    rescue => e
      Rails.logger.error "❌ push_message error: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.first(5).join("\n")}"
    end
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

  # 🆕 表示用住所を取得
  def get_display_address(user)
    if user.booking_location == 'other'
      # 別の場所の場合はキャッシュから住所を取得
      other_address = Rails.cache.read("other_location_address_#{user.id}")
      if other_address.present?
        return truncate_address(other_address)
      else
        return "別の場所（住所未設定）"
      end
    elsif user.booking_location == 'rental'
      # レンタルスペースの場合は専用メッセージ
      return "レンタルスペース（手配予定）"
    elsif user.address.present?
      # 自宅または通常の住所（自宅の場合は「自宅:」プレフィックスを付ける）
      if user.booking_location == 'home' || user.address.include?("自宅:")
        return truncate_address("自宅: #{user.address.gsub('自宅: ', '')}")
      else
        return truncate_address(user.address)
      end
    else
      return "住所未設定"
    end
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
      # 営業日チェック（一時的に日曜日も含める）
      # next if date.sunday?
      
      # その日に空きがあるかチェック（より緩やかな条件）
      if has_available_slots_on_date(date)
        dates << date
      end
    end
    Rails.logger.info "📅 get_available_dates: Found #{dates.count} available dates: #{dates.map(&:strftime).join(', ')}"
    dates
  end

  def has_available_slots_on_date(date)
    # より緩やかなチェック：その日の予約数が一定数以下なら空きありとする
    reservations_count = Reservation.active
      .where(start_time: date.beginning_of_day..date.end_of_day)
      .count
    
    Rails.logger.info "📅 has_available_slots_on_date: #{date.strftime} has #{reservations_count} reservations"
    reservations_count < 12 # 1日最大12枠に緩和（10:00-20:00で30分間隔なら20枠可能）
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
      
      # 重複チェック（Reservationモデルのno_time_overlapと同じロジック）
      overlapping = Reservation.active
        .where.not(id: nil)
        .select do |other|
          # 各予約のインターバル時間を取得（デフォルト10分）
          other_interval = other.respond_to?(:effective_interval_minutes) ? other.effective_interval_minutes : 10
          other_end_with_interval = other.end_time + other_interval.minutes
          
          # 現在のスロットのインターバル時間を取得（デフォルト10分）
          current_interval = 10 # デフォルト値
          current_end_with_interval = end_time + current_interval.minutes
          
          # 重複判定（インターバル時間も含む）
          overlap = current_time < other_end_with_interval && current_end_with_interval > other.start_time
          
          overlap
        end
      
      unless overlapping.any?
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

  # 🆕 日付選択画面を表示（push_message使用）
  def start_date_selection_with_push(user, course)
    Rails.logger.info "📅 start_date_selection_with_push called for user #{user.id}, course: #{course}"
    
    # 利用可能な日付を表示
    available_dates = get_available_dates(7) # 今日から7日間
    Rails.logger.info "📅 Found #{available_dates.count} available dates: #{available_dates.map(&:strftime).join(', ')}"
    
    if available_dates.empty?
      Rails.logger.info "❌ No available dates found"
      push_message(user.line_user_id, {
        type: "text",
        text: "申し訳ございません。現在予約可能な日程がございません。\nお電話でお問い合わせください: 03-1234-5678"
      })
      return
    end
    
    Rails.logger.info "📝 Creating date selection message"
    
    # コース名をURLセーフな形式に変換
    course_safe = course.gsub(/[^\w\s]/, '').gsub(/\s+/, '_')
    
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
            Rails.logger.info "📝 Creating date button for #{date.strftime('%Y-%m-%d')}"
            {
              type: "button",
              style: "secondary",
              action: {
                type: "postback",
                label: date.strftime('%m/%d (%a)'),
                data: "select_date_#{course_safe}_#{date.strftime('%Y-%m-%d')}"
              }
            }
          },
          spacing: "sm"
        }
      }
    }
    
    Rails.logger.info "📤 Pushing date selection message"
    push_message(user.line_user_id, message)
    Rails.logger.info "✅ Date selection message pushed successfully"
  end

  # 🆕 Googleレビュー投稿URLを取得
  def get_google_review_url
    # 環境変数から取得、なければデフォルトの検索URL
    ENV['GOOGLE_REVIEW_URL'] || "https://www.google.com/search?q=mobilis+stretch+reviews&tbm=lcl"
  end

  # 🆕 GoogleビジネスプロフィールURLを取得
  def get_google_business_url
    # 環境変数から取得、なければデフォルトの検索URL
    ENV['GOOGLE_BUSINESS_URL'] || "https://www.google.com/search?q=mobilis+stretch+reviews&tbm=lcl"
  end

  # 🆕 予約確認メニュー送信
  def send_reservation_check(user, reply_token)
    Rails.logger.info "🔍 send_reservation_check called for user: #{user.id}"
    
    # ユーザーの今後の予約を取得（キャンセル済みを除外）
    upcoming_reservations = user.reservations
                               .where('start_time > ?', Time.current)
                               .where.not(status: 'cancelled')
                               .order(:start_time)
                               .limit(5)

    Rails.logger.info "🔍 Found #{upcoming_reservations.count} upcoming reservations"

    if upcoming_reservations.empty?
      message = {
        type: "flex",
        altText: get_message(user, :reservation_check_title),
        contents: {
          type: "bubble",
          header: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: get_message(user, :reservation_check_title),
                weight: "bold",
                size: "xl",
                color: "#FF6B35"
              },
              {
                type: "text",
                text: get_message(user, :reservation_check_title_en),
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
                text: get_message(user, :no_upcoming_reservations),
                size: "md",
                color: "#666666",
                wrap: true
              },
              {
                type: "text",
                text: get_message(user, :no_upcoming_reservations_en),
                size: "sm",
                color: "#999999",
                wrap: true,
                margin: "xs"
              },
              {
                type: "text",
                text: get_message(user, :no_upcoming_reservations_sub),
                size: "sm",
                color: "#999999",
                wrap: true,
                margin: "md"
              },
              {
                type: "text",
                text: get_message(user, :no_upcoming_reservations_sub_en),
                size: "sm",
                color: "#999999",
                wrap: true,
                margin: "xs"
              }
            ],
            paddingAll: "20px"
          },
          footer: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "button",
                action: {
                  type: "postback",
                  label: get_message(user, :new_reservation),
                  data: "booking"
                },
                style: "primary",
                color: "#FF6B35"
              },
              {
                type: "text",
                text: get_message(user, :new_reservation_en),
                size: "sm",
                color: "#999999",
                align: "center",
                margin: "xs"
              }
            ],
            paddingAll: "20px"
          }
        }
      }
    else
      # 予約がある場合のFlex Message
      reservation_items = upcoming_reservations.map do |reservation|
        {
          type: "box",
          layout: "vertical",
          contents: [
            {
              type: "text",
              text: "📅 #{reservation.start_time.strftime('%m/%d %H:%M')}~",
              weight: "bold",
              size: "md",
              color: "#FF6B35"
            },
            {
              type: "box",
              layout: "horizontal",
              contents: [
                {
                  type: "text",
                  text: reservation.status == 'confirmed' ? get_message(user, :confirmed) : get_message(user, :tentative),
                  size: "sm",
                  color: reservation.status == 'confirmed' ? "#00C851" : "#FF8800",
                  flex: 0
                },
                {
                  type: "text",
                  text: reservation.status == 'confirmed' ? get_message(user, :confirmed_en) : get_message(user, :tentative_en),
                  size: "sm",
                  color: reservation.status == 'confirmed' ? "#00C851" : "#FF8800",
                  flex: 0,
                  margin: "sm"
                }
              ],
              margin: "sm"
            },
            {
              type: "text",
              text: "📍 #{(reservation.course || 'コース未設定').to_s.gsub(/分$/, '')}min",
              size: "sm",
              color: "#666666",
              margin: "sm"
            }
          ],
          margin: "md",
          paddingAll: "12px",
          backgroundColor: "#F8F9FA",
          cornerRadius: "8px"
        }
      end

      message = {
        type: "flex",
        altText: get_message(user, :reservation_check_title),
        contents: {
          type: "bubble",
          header: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: get_message(user, :reservation_check_title),
                weight: "bold",
                size: "xl",
                color: "#FF6B35"
              },
              {
                type: "text",
                text: get_message(user, :reservation_check_title_en),
                size: "sm",
                color: "#999999",
                margin: "xs"
              },
              {
                type: "text",
                text: get_message(user, :reservation_check_subtitle),
                size: "sm",
                color: "#666666",
                margin: "sm"
              },
              {
                type: "text",
                text: get_message(user, :reservation_check_subtitle_en),
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
            contents: reservation_items,
            paddingAll: "20px"
          },
            footer: {
              type: "box",
              layout: "vertical",
              contents: [
                {
                  type: "button",
                  action: {
                    type: "postback",
                    label: get_message(user, :new_reservation),
                    data: "booking"
                  },
                  style: "primary",
                  color: "#4CAF50"
                },
                {
                  type: "text",
                  text: get_message(user, :new_reservation_en),
                  size: "sm",
                  color: "#999999",
                  align: "center",
                  margin: "xs"
                },
                {
                  type: "button",
                  action: {
                    type: "postback",
                    label: get_message(user, :cancel_reservation),
                    data: "cancel_reservation_menu"
                  },
                  style: "secondary",
                  color: "#FF9800",
                  margin: "sm"
                },
                {
                  type: "text",
                  text: get_message(user, :cancel_reservation_en),
                  size: "sm",
                  color: "#999999",
                  align: "center",
                  margin: "xs"
                }
              ],
              paddingAll: "20px"
            }
        }
      }
    end

    Rails.logger.info "🔍 Sending reservation check message to user: #{user.id}"
    send_reply(reply_token, message)
    Rails.logger.info "✅ Reservation check message sent successfully"
  end

  # 🆕 予約キャンセルメニュー送信
  def send_cancel_reservation_menu(user, reply_token)
    # ユーザーの今後の予約を取得
    upcoming_reservations = user.reservations
                               .where('start_time > ?', Time.current)
                               .where(status: ['confirmed', 'tentative'])
                               .order(:start_time)
                               .limit(5)

    if upcoming_reservations.empty?
      message = {
        type: "flex",
        altText: get_message(user, :cancel_menu_title),
        contents: {
          type: "bubble",
          header: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: get_message(user, :cancel_menu_title),
                weight: "bold",
                size: "xl",
                color: "#DC3545"
              },
              {
                type: "text",
                text: get_message(user, :cancel_menu_title_en),
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
                text: get_message(user, :no_reservations),
                size: "md",
                color: "#666666",
                wrap: true
              },
              {
                type: "text",
                text: get_message(user, :no_reservations_en),
                size: "sm",
                color: "#999999",
                wrap: true,
                margin: "xs"
              }
            ],
            paddingAll: "20px"
          },
          footer: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "button",
                action: {
                  type: "postback",
                  label: get_message(user, :return_to_check),
                  data: "check_reservations"
                },
                style: "secondary",
                color: "#6C757D"
              }
            ],
            paddingAll: "20px"
          }
        }
      }
    else
      # キャンセル可能な予約がある場合
      reservation_buttons = upcoming_reservations.map do |reservation|
        {
          type: "button",
          action: {
            type: "postback",
            label: "#{reservation.start_time.strftime('%m/%d %H:%M')}~ #{reservation.course.to_s.gsub(/分$/, '')}min",
            data: "cancel_reservation_#{reservation.id}"
          },
          style: "secondary",
          margin: "sm"
        }
      end

      message = {
        type: "flex",
        altText: get_message(user, :cancel_menu_title),
        contents: {
          type: "bubble",
          header: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "text",
                text: get_message(user, :cancel_menu_title),
                weight: "bold",
                size: "xl",
                color: "#DC3545"
              },
              {
                type: "text",
                text: get_message(user, :cancel_menu_title_en),
                size: "sm",
                color: "#999999",
                margin: "xs"
              },
              {
                type: "text",
                text: get_message(user, :cancel_menu_subtitle),
                size: "sm",
                color: "#666666",
                margin: "sm"
              },
              {
                type: "text",
                text: get_message(user, :cancel_menu_subtitle_en),
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
            contents: reservation_buttons,
            paddingAll: "0px",
            paddingStart: "20px",
            paddingEnd: "20px"
          },
          footer: {
            type: "box",
            layout: "vertical",
            contents: [
              {
                type: "button",
                action: {
                  type: "postback",
                  label: get_message(user, :return_to_check),
                  data: "check_reservations"
                },
                style: "primary",
                color: "#FF9800",
                margin: "sm"
              },
              {
                type: "text",
                text: get_message(user, :return_to_check_en),
                size: "sm",
                color: "#999999",
                align: "center",
                margin: "xs"
              }
            ],
            paddingAll: "10px"
          }
        }
      }
    end

    send_reply(reply_token, message)
  end

  # 🆕 予約キャンセル処理
  def cancel_reservation(user, reservation_id, reply_token)
    Rails.logger.info "🔍 Starting cancellation for reservation ID: #{reservation_id}, user: #{user.id}"
    
    reservation = user.reservations.find_by(id: reservation_id)
    
    unless reservation
      Rails.logger.error "❌ Reservation not found: #{reservation_id}"
      send_reply(reply_token, {
        type: "text",
        text: "❌ 予約が見つかりませんでした。"
      })
      return
    end

    Rails.logger.info "🔍 Found reservation: #{reservation.id}, status: #{reservation.status}, start_time: #{reservation.start_time}"

    unless ['confirmed', 'tentative'].include?(reservation.status)
      Rails.logger.warn "❌ Cannot cancel reservation with status: #{reservation.status}"
      send_reply(reply_token, {
        type: "text",
        text: "❌ この予約はキャンセルできません。（ステータス: #{reservation.status}）"
      })
      return
    end

    # 予約をキャンセル
    begin
      reservation.skip_time_validation = true
      # skip_cancellation_notifications = true を削除して、通常のキャンセル通知を使用
      reservation.update!(
        status: 'cancelled',
        cancelled_at: Time.current,
        cancellation_reason: 'ユーザーによるキャンセル'
      )
      Rails.logger.info "✅ Reservation #{reservation_id} cancelled successfully"
    rescue => e
      Rails.logger.error "❌ Failed to cancel reservation #{reservation_id}: #{e.message}"
      send_reply(reply_token, {
        type: "text",
        text: "❌ キャンセル処理中にエラーが発生しました。"
      })
      return
    end

    # 元々のキャンセル通知を使用するため、追加のメッセージは送信しない
  end
end

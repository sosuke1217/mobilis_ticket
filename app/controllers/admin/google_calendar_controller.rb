# app/controllers/admin/google_calendar_controller.rb
# Googleカレンダー同期管理コントローラー

class Admin::GoogleCalendarController < ApplicationController
  before_action :authenticate_admin_user!, except: [:webhook]
  skip_before_action :verify_authenticity_token, only: [:webhook]

  def index
    begin
      @sync_enabled = ENV['GOOGLE_CALENDAR_SYNC_ENABLED'] == 'true'
      @credentials_exist = File.exist?(Rails.root.join('config', 'google_calendar_credentials.json'))
      # データベースまたはファイルにトークンが存在するか確認
      @token_exist = GoogleCalendarToken.exists?(user_id: 'default') || File.exist?(Rails.root.join('config', 'google_calendar_token.yaml'))
      # アクティブなWebhookチャンネルを取得
      @active_channel = GoogleCalendarChannel.active.first
    rescue => e
      Rails.logger.error "❌ Error in GoogleCalendarController#index: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.first(5).join("\n")}"
      @sync_enabled = false
      @credentials_exist = false
      @token_exist = false
      @active_channel = nil
      flash[:alert] = "設定の読み込み中にエラーが発生しました: #{e.message}"
    end
  end

  def authorize
    begin
      auth_url = GoogleCalendarSync.get_authorization_url
      if auth_url
        redirect_to auth_url, allow_other_host: true
      else
        flash[:alert] = "認証URLの取得に失敗しました。認証情報ファイルが正しく設定されているか確認してください。"
        redirect_to admin_google_calendar_index_path
      end
    rescue => e
      flash[:alert] = "認証エラー: #{e.message}"
      redirect_to admin_google_calendar_index_path
    end
  end

  def callback
    code = params[:code]
    if code.present?
      begin
        credentials = GoogleCalendarSync.authorize_with_code(code)
        if credentials
          flash[:notice] = "Googleカレンダーとの認証が完了しました"
        else
          flash[:alert] = "認証に失敗しました。認証コードが正しいか確認してください。"
        end
      rescue => e
        flash[:alert] = "認証エラー: #{e.message}"
      end
    else
      flash[:alert] = "認証コードが取得できませんでした。"
    end
    redirect_to admin_google_calendar_index_path
  end

  def sync_to_google
    # 予約をGoogleカレンダーに同期
    begin
      sync_service = GoogleCalendarSync.new
      reservations = Reservation.where('start_time >= ?', Time.current)
                                 .where.not(status: :cancelled)
                                 .where(google_calendar_event_id: nil)
      
      synced_count = 0
      reservations.find_each do |reservation|
        begin
          sync_service.create_event(reservation)
          synced_count += 1
        rescue => e
          Rails.logger.error "Failed to sync reservation #{reservation.id}: #{e.message}"
        end
      end

      flash[:notice] = "#{synced_count}件の予約をGoogleカレンダーに同期しました"
    rescue => e
      flash[:alert] = "同期エラー: #{e.message}"
    end
    
    redirect_to admin_google_calendar_index_path
  end

  def sync_from_google
    # Googleカレンダーから予約を同期
    begin
      sync_service = GoogleCalendarSync.new
      result = sync_service.sync_events_to_reservations(
        start_time: Time.current.beginning_of_day,
        end_time: 30.days.from_now.end_of_day
      )
      
      flash[:notice] = "Googleカレンダーから同期しました（新規: #{result[:created]}件、更新: #{result[:updated]}件）"
    rescue => e
      flash[:alert] = "同期エラー: #{e.message}"
    end
    
    redirect_to admin_google_calendar_index_path
  end

  def test_connection
    begin
      sync_service = GoogleCalendarSync.new
      events = sync_service.fetch_events(
        start_time: Time.current.beginning_of_day,
        end_time: 1.day.from_now.end_of_day
      )
      
      flash[:notice] = "接続成功: #{events.count}件のイベントを取得しました"
    rescue => e
      flash[:alert] = "接続エラー: #{e.message}"
    end
    
    redirect_to admin_google_calendar_index_path
  end

  # Webhookエンドポイント（Googleからの通知を受け取る）
  def webhook
    channel_id = request.headers['X-Goog-Channel-Id']
    resource_id = request.headers['X-Goog-Resource-Id']
    resource_state = request.headers['X-Goog-Resource-State']
    resource_uri = request.headers['X-Goog-Resource-URI']
    
    Rails.logger.info "🔔 Google Calendar webhook received: channel_id=#{channel_id}, state=#{resource_state}"
    
    # 初回の通知（sync）は無視
    if resource_state == 'sync'
      Rails.logger.info "⏭️ Initial sync notification, skipping"
      head :ok
      return
    end
    
    # 変更通知の場合、同期を実行
    if resource_state == 'exists' || resource_state == 'not_exists'
      begin
        sync_service = GoogleCalendarSync.new
        result = sync_service.sync_events_to_reservations(
          start_time: Time.current.beginning_of_day,
          end_time: 30.days.from_now.end_of_day
        )
        Rails.logger.info "✅ Webhook sync completed: #{result[:synced]} events processed (#{result[:created]} created, #{result[:updated]} updated)"
      rescue => e
        Rails.logger.error "❌ Webhook sync error: #{e.message}"
        Rails.logger.error "❌ Backtrace: #{e.backtrace.first(5).join("\n")}"
      end
    end
    
    head :ok
  end

  # Webhookチャンネルを登録
  def register_webhook
    begin
      sync_service = GoogleCalendarSync.new
      
      # Webhook URLを構築（HTTPSを強制）
      protocol = Rails.env.production? ? 'https' : request.protocol
      host = Rails.env.production? ? (ENV['HEROKU_APP_NAME'] ? "#{ENV['HEROKU_APP_NAME']}.herokuapp.com" : request.host_with_port) : request.host_with_port
      webhook_url = "#{protocol}://#{host}/admin/google_calendar/webhook"
      
      Rails.logger.info "🔄 Registering webhook with URL: #{webhook_url}"
      
      # 既存のチャンネルを停止
      GoogleCalendarChannel.active.find_each do |channel|
        sync_service.stop_channel(channel.channel_id, channel.resource_id)
      end
      
      # 新しいチャンネルを登録
      result = sync_service.watch_calendar(webhook_url)
      
      if result
        flash[:notice] = "Webhookチャンネルを登録しました（有効期限: #{Time.at(result.expiration / 1000).strftime('%Y年%m月%d日 %H:%M')}）"
      else
        flash[:alert] = "Webhookチャンネルの登録に失敗しました"
      end
    rescue => e
      flash[:alert] = "Webhook登録エラー: #{e.message}"
      Rails.logger.error "❌ Webhook registration error: #{e.message}"
    end
    
    redirect_to admin_google_calendar_index_path
  end

  # Webhookチャンネルを停止
  def stop_webhook
    begin
      sync_service = GoogleCalendarSync.new
      
      GoogleCalendarChannel.active.find_each do |channel|
        sync_service.stop_channel(channel.channel_id, channel.resource_id)
      end
      
      flash[:notice] = "Webhookチャンネルを停止しました"
    rescue => e
      flash[:alert] = "Webhook停止エラー: #{e.message}"
      Rails.logger.error "❌ Webhook stop error: #{e.message}"
    end
    
    redirect_to admin_google_calendar_index_path
  end
end


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
      
      # 同期統計を取得
      if @sync_enabled && @token_exist
        @sync_stats = {
          total_reservations: Reservation.where('start_time >= ?', Time.current).where.not(status: :cancelled).count,
          synced_reservations: Reservation.where('start_time >= ?', Time.current).where.not(status: :cancelled).where.not(google_calendar_event_id: nil).count,
          unsynced_reservations: Reservation.where('start_time >= ?', Time.current).where.not(status: :cancelled).where(google_calendar_event_id: nil).count,
          recently_synced: Reservation.where('start_time >= ?', Time.current).where.not(status: :cancelled).where('google_calendar_synced_at > ?', 24.hours.ago).count
        }
      else
        @sync_stats = nil
      end
    rescue => e
      Rails.logger.error "❌ Error in GoogleCalendarController#index: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.first(5).join("\n")}"
      @sync_enabled = false
      @credentials_exist = false
      @token_exist = false
      @active_channel = nil
      @sync_stats = nil
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
      busy_periods = sync_service.busy_periods(
        start_time: Time.current.beginning_of_day,
        end_time: 1.day.from_now.end_of_day
      )

      if busy_periods.nil?
        flash[:alert] = "接続エラー: Googleカレンダーの認証が無効です。再認証してください。"
      else
        flash[:notice] = "接続成功: Googleカレンダーの空き状況を取得できました"
      end
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
    
    # セキュリティ検証: 必須ヘッダーの確認
    unless channel_id.present? && resource_id.present? && resource_state.present?
      Rails.logger.warn "⚠️ Invalid webhook request: missing required headers"
      head :bad_request
      return
    end
    
    # セキュリティ検証: チャンネルIDの検証（登録されているチャンネルのみ受け入れる）
    unless GoogleCalendarChannel.exists?(channel_id: channel_id)
      Rails.logger.warn "⚠️ Invalid webhook request: unknown channel_id #{channel_id}"
      head :forbidden
      return
    end
    
    # セキュリティ検証: Resource IDの検証
    channel = GoogleCalendarChannel.find_by(channel_id: channel_id)
    if channel && channel.resource_id != resource_id
      Rails.logger.warn "⚠️ Invalid webhook request: resource_id mismatch. Expected: #{channel.resource_id}, Got: #{resource_id}"
      head :forbidden
      return
    end
    
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

      # Webhook URLを構築（本番は必ずHTTPS・ポートなし）
      if Rails.env.production?
        protocol = 'https'
        host = ENV['HEROKU_APP_NAME'].presence || request.host
        host = host.sub(/:443\z/, '') # :443 を除去
        webhook_url = "#{protocol}://#{host}/admin/google_calendar/webhook"
      else
        webhook_url = "#{request.protocol}#{request.host_with_port}/admin/google_calendar/webhook"
      end

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
        flash[:alert] = "Webhookチャンネルの登録に失敗しました（認証されていない可能性があります）"
      end
    rescue => e
      msg = e.message.to_s
      if msg.include?('invalid_grant') || msg.include?('expired') || msg.include?('revoked')
        flash[:alert] = "Googleカレンダーの認証の有効期限が切れています。「認証する」ボタンから再度Googleアカウントで認証してから、Webhookを登録してください。"
      elsif msg.include?('invalid') && msg.include?('address')
        flash[:alert] = "Webhook登録エラー: #{msg}（WebhookのURLはHTTPSで、Googleから到達可能である必要があります。本番ではHEROKU_APP_NAMEの設定を確認してください）"
      else
        flash[:alert] = "Webhook登録エラー: #{msg}"
      end
      Rails.logger.error "❌ Webhook registration error: #{e.class} #{e.message}"
      Rails.logger.error e.backtrace.first(8).join("\n")
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


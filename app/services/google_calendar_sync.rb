# app/services/google_calendar_sync.rb
# Googleカレンダーとの双方向同期サービス

require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'set'

class GoogleCalendarSync
  CALENDAR_ID = 'primary' # プライマリカレンダーを使用

  def initialize
    @service = Google::Apis::CalendarV3::CalendarService.new
    Rails.logger.info "🔄 GoogleCalendarSync initializing..."
    Rails.logger.info "🔄 Credentials file exists: #{File.exist?(credentials_path)}"
    Rails.logger.info "🔄 Token file exists: #{File.exist?(token_path)}"
    @service.authorization = authorize
    Rails.logger.info "🔄 Authorization result: #{@service.authorization.present? ? 'SUCCESS' : 'FAILED'}"
  end

  # 予約をGoogleカレンダーに作成
  def create_event(reservation)
    Rails.logger.info "🔄 create_event called for reservation #{reservation.id}"
    Rails.logger.info "🔄 authorized? = #{authorized?}"
    
    unless authorized?
      Rails.logger.error "❌ Not authorized to create Google Calendar event"
      return nil
    end

    begin
      event = build_event_from_reservation(reservation)
      Rails.logger.info "🔄 Event built: #{event.summary} from #{event.start.date_time} to #{event.end.date_time}"
      Rails.logger.info "🔄 Event color_id: #{event.color_id.inspect}"
      Rails.logger.info "🔄 Event extended_properties: #{event.extended_properties.inspect}"
      
      result = @service.insert_event(CALENDAR_ID, event)
      reservation.update_columns(
        google_calendar_event_id: result.id,
        google_calendar_synced_at: Time.current
      )
      Rails.logger.info "✅ Google Calendar event created: #{result.id} for reservation #{reservation.id}"
      result
    rescue => e
      Rails.logger.error "❌ Failed to create Google Calendar event: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.first(5).join("\n")}"
      raise
    end
  end

  # 予約をGoogleカレンダーで更新
  def update_event(reservation)
    return unless authorized?
    return unless reservation.google_calendar_event_id.present?

    event = @service.get_event(CALENDAR_ID, reservation.google_calendar_event_id)
    update_event_from_reservation(event, reservation)
    
    begin
      result = @service.update_event(CALENDAR_ID, reservation.google_calendar_event_id, event)
      reservation.update_column(:google_calendar_synced_at, Time.current)
      Rails.logger.info "✅ Google Calendar event updated: #{result.id} for reservation #{reservation.id}"
      result
    rescue => e
      Rails.logger.error "❌ Failed to update Google Calendar event: #{e.message}"
      raise
    end
  end

  # 予約をGoogleカレンダーから削除
  def delete_event(reservation)
    return unless authorized?
    return unless reservation.google_calendar_event_id.present?

    begin
      @service.delete_event(CALENDAR_ID, reservation.google_calendar_event_id)
      reservation.update_columns(
        google_calendar_event_id: nil,
        google_calendar_synced_at: nil
      )
      Rails.logger.info "✅ Google Calendar event deleted for reservation #{reservation.id}"
      true
    rescue Google::Apis::ClientError => e
      if e.status_code == 404
        # イベントが既に削除されている場合は成功として扱う
        reservation.update_columns(
          google_calendar_event_id: nil,
          google_calendar_synced_at: nil
        )
        Rails.logger.warn "⚠️ Google Calendar event not found (already deleted): #{reservation.google_calendar_event_id}"
        true
      else
        Rails.logger.error "❌ Failed to delete Google Calendar event: #{e.message}"
        raise
      end
    rescue => e
      Rails.logger.error "❌ Failed to delete Google Calendar event: #{e.message}"
      raise
    end
  end

  # Googleカレンダーからイベントを取得（指定期間）
  def fetch_events(start_time: Time.current.beginning_of_day, end_time: 30.days.from_now.end_of_day)
    return [] unless authorized?

    begin
      response = @service.list_events(
        CALENDAR_ID,
        time_min: start_time.iso8601,
        time_max: end_time.iso8601,
        single_events: true,
        order_by: 'startTime'
      )
      response.items || []
    rescue => e
      Rails.logger.error "❌ Failed to fetch Google Calendar events: #{e.message}"
      []
    end
  end

  # Return busy periods directly from Google Calendar without importing them as
  # Reservation records. This is used by the public booking screen so its
  # availability is always based on the latest Google Calendar state.
  #
  # nil means Google Calendar could not be checked. An empty array means the
  # calendar was checked successfully and there are no busy periods.
  def busy_periods(start_time:, end_time:)
    unless authorized?
      GoogleCalendarHealth.record_failure!("Google Calendar authorization is unavailable")
      return nil
    end

    request = Google::Apis::CalendarV3::FreeBusyRequest.new(
      time_min: start_time.to_datetime,
      time_max: end_time.to_datetime,
      time_zone: Time.zone.tzinfo.name,
      items: [Google::Apis::CalendarV3::FreeBusyRequestItem.new(id: CALENDAR_ID)]
    )

    response = @service.query_freebusy(request)
    calendars = response.calendars || {}

    periods = calendars.values.flat_map { |calendar| calendar.busy || [] }.map do |period|
      {
        start_time: Time.zone.parse(period.start.to_s),
        end_time: Time.zone.parse(period.end.to_s)
      }
    end

    GoogleCalendarHealth.record_success!
    periods
  rescue => e
    Rails.logger.error "❌ Failed to fetch Google Calendar free/busy data: #{e.message}"
    GoogleCalendarHealth.record_failure!(e.message)
    nil
  end

  # Googleカレンダーのイベントを予約として同期
  def sync_events_to_reservations(start_time: Time.current.beginning_of_day, end_time: 30.days.from_now.end_of_day)
    return unless authorized?

    events = fetch_events(start_time: start_time, end_time: end_time)
    synced_count = 0
    created_count = 0
    updated_count = 0
    deleted_count = 0

    # Googleカレンダーに存在するイベントIDのセットを作成
    event_ids = Set.new
    events.each do |event|
      next if event.start.date_time.nil? # 終日イベントはスキップ
      event_ids.add(event.id)
    end

    # イベントを処理
    events.each do |event|
      next if event.start.date_time.nil? # 終日イベントはスキップ
      
      # 既存の予約を検索
      # 1. GoogleカレンダーイベントIDで検索
      reservation = Reservation.find_by(google_calendar_event_id: event.id)
      
      # 2. イベントIDで見つからない場合、extended_propertiesのreservation_idで検索
      if reservation.nil?
        reservation_id_from_event = event.extended_properties&.private&.dig('reservation_id')
        if reservation_id_from_event.present?
          reservation = Reservation.find_by(id: reservation_id_from_event)
          # 見つかった場合、google_calendar_event_idを更新（イベントIDが変わった場合に対応）
          if reservation && reservation.google_calendar_event_id != event.id
            Rails.logger.info "🔄 Updating google_calendar_event_id for reservation #{reservation.id}: #{reservation.google_calendar_event_id} -> #{event.id}"
            reservation.update_column(:google_calendar_event_id, event.id)
          end
        end
      end

      if reservation
        # 既存の予約は常に更新（時間変更などに対応）
        # ただし、キャンセル済みの予約は更新しない
        unless reservation.cancelled?
          update_reservation_from_event(reservation, event)
          updated_count += 1
        end
        synced_count += 1
      else
        # 新規作成（Googleカレンダーから直接作成された予約も含む）
        reservation = create_reservation_from_event(event)
        if reservation
          created_count += 1
          synced_count += 1
        end
      end
    end

    # 同期範囲内の予約で、Googleカレンダーに存在しないものを検出して削除
    reservations_with_google_id = Reservation.where('start_time >= ? AND start_time <= ?', start_time, end_time)
                                             .where.not(google_calendar_event_id: nil)
                                             .where.not(status: :cancelled)

    reservations_with_google_id.find_each do |reservation|
      unless event_ids.include?(reservation.google_calendar_event_id)
        Rails.logger.info "🗑️ Google Calendar event deleted: #{reservation.google_calendar_event_id}, cancelling reservation #{reservation.id}"
        
        # 予約をキャンセル（削除ではなくキャンセルで履歴を残す）
        reservation.update_columns(
          status: :cancelled,
          cancelled_at: Time.current,
          cancellation_reason: 'Googleカレンダーから削除されました'
        )
        
        # Googleカレンダー同期フラグをクリア（無限ループを防ぐ）
        reservation.update_column(:google_calendar_synced_at, nil)
        
        deleted_count += 1
        synced_count += 1
      end
    end

    Rails.logger.info "✅ Google Calendar sync completed: #{synced_count} events processed (#{created_count} created, #{updated_count} updated, #{deleted_count} deleted)"
    { synced: synced_count, created: created_count, updated: updated_count, deleted: deleted_count }
  end

  # 認証済みかチェック
  def authorized?
    @service.authorization.present?
  end

  # チャンネルを登録（Webhookを開始）
  def watch_calendar(webhook_url, channel_id = SecureRandom.uuid)
    unless authorized?
      Rails.logger.error "❌ Cannot register webhook: not authorized (token missing or invalid)"
      raise "Googleカレンダーに認証されていません。先に「認証する」から再度認証してください。"
    end

    Rails.logger.info "🔄 Registering webhook channel: #{channel_id}, URL: #{webhook_url}"
    
    # 既存のチャンネルを確認（同じURLで既に登録されている場合）
    existing_channel = GoogleCalendarChannel.active.find_by(webhook_url: webhook_url)
    if existing_channel && existing_channel.expiration > 1.day.from_now
      Rails.logger.info "⏭️ Active channel already exists for this URL, skipping registration"
      return Google::Apis::CalendarV3::Channel.new(
        id: existing_channel.channel_id,
        resource_id: existing_channel.resource_id,
        expiration: existing_channel.expiration.to_i * 1000
      )
    end
    
    channel = Google::Apis::CalendarV3::Channel.new(
      id: channel_id,
      type: 'web_hook',
      address: webhook_url,
      expiration: (Time.current + 7.days).to_i * 1000  # 7日間有効（ミリ秒）
    )
    
    begin
      result = @service.watch_event(CALENDAR_ID, channel)
      Rails.logger.info "✅ Channel registered: #{result.id}, resource_id: #{result.resource_id}, expiration: #{Time.at(result.expiration / 1000)}"

      # チャンネル情報をデータベースに保存（新規のみ。既存は update で上書き）
      record = GoogleCalendarChannel.find_or_initialize_by(channel_id: channel_id)
      record.assign_attributes(
        resource_id: result.resource_id,
        expiration: Time.at(result.expiration / 1000),
        webhook_url: webhook_url
      )
      record.save!

      result
    rescue => e
      Rails.logger.error "❌ Failed to register channel: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.first(10).join("\n")}"
      raise
    end
  end

  # チャンネルを停止
  def stop_channel(channel_id, resource_id)
    return false unless authorized?
    
    Rails.logger.info "🔄 Stopping channel: #{channel_id}"
    
    channel = Google::Apis::CalendarV3::Channel.new(
      id: channel_id,
      resource_id: resource_id
    )
    
    begin
      @service.stop_channel(channel)
      Rails.logger.info "✅ Channel stopped: #{channel_id}"
      
      # データベースから削除
      GoogleCalendarChannel.find_by(channel_id: channel_id)&.destroy
      
      true
    rescue => e
      Rails.logger.error "❌ Failed to stop channel: #{e.message}"
      false
    end
  end

  private

  # OAuth認証
  def authorize
    Rails.logger.info "🔄 authorize called"
    Rails.logger.info "🔄 credentials_path: #{credentials_path}"
    Rails.logger.info "🔄 credentials_path exists: #{File.exist?(credentials_path)}"
    Rails.logger.info "🔄 token_path: #{token_path}"
    Rails.logger.info "🔄 token_path exists: #{File.exist?(token_path)}"
    
    return nil unless File.exist?(credentials_path)
    
    begin
      client_id = Google::Auth::ClientId.from_file(credentials_path)
      # データベースにトークンが存在する場合はデータベースストアを使用、なければファイルストアを使用（後方互換性）
      token_store = if GoogleCalendarToken.exists?(user_id: 'default')
        GoogleAuthStores::DatabaseTokenStore.new
      else
        Google::Auth::Stores::FileTokenStore.new(file: token_path)
      end
      authorizer = Google::Auth::UserAuthorizer.new(client_id, Google::Apis::CalendarV3::AUTH_CALENDAR, token_store)
      
      user_id = 'default'
      credentials = authorizer.get_credentials(user_id)
      
      if credentials.nil?
        Rails.logger.warn "⚠️ No credentials found for user_id: #{user_id}"
        # 認証が必要な場合はnilを返す（コントローラーで処理）
        return nil
      end
      
      Rails.logger.info "✅ Authorization successful"
      credentials
    rescue => e
      Rails.logger.error "❌ Google Calendar authorization failed: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.first(5).join("\n")}"
      nil
    end
  end

  # 認証URLを取得
  def self.get_authorization_url(base_url:, state:)
    return nil unless File.exist?(Rails.root.join('config', 'google_calendar_credentials.json'))

    client_id = Google::Auth::ClientId.from_file(Rails.root.join('config', 'google_calendar_credentials.json'))
    token_store = GoogleAuthStores::DatabaseTokenStore.new
    authorizer = Google::Auth::UserAuthorizer.new(client_id, Google::Apis::CalendarV3::AUTH_CALENDAR, token_store)

    authorizer.get_authorization_url(base_url: base_url, state: state)
  rescue => e
    Rails.logger.error "❌ Failed to get authorization URL: #{e.message}"
    nil
  end

  # GoogleのWebコールバックで受け取った認証コードからトークンを取得
  def self.authorize_with_code(code, base_url:)
    return nil unless File.exist?(Rails.root.join('config', 'google_calendar_credentials.json'))

    client_id = Google::Auth::ClientId.from_file(Rails.root.join('config', 'google_calendar_credentials.json'))
    token_store = GoogleAuthStores::DatabaseTokenStore.new
    authorizer = Google::Auth::UserAuthorizer.new(client_id, Google::Apis::CalendarV3::AUTH_CALENDAR, token_store)

    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: 'default',
      code: code,
      base_url: base_url
    )

    Rails.logger.info "✅ Google Calendar authorization completed"
    credentials
  rescue => e
    Rails.logger.error "❌ Failed to authorize with code: #{e.message}"
    nil
  end

  # 認証情報ファイルのパス
  def credentials_path
    Rails.root.join('config', 'google_calendar_credentials.json')
  end

  # トークンファイルのパス
  def token_path
    Rails.root.join('config', 'google_calendar_token.yaml')
  end

  # 予約からGoogleカレンダーイベントを構築
  def build_event_from_reservation(reservation)
    Rails.logger.info "🔄 Building event for reservation #{reservation.id}"
    
    begin
      # ExtendedPropertiesを構築
      extended_props = Google::Apis::CalendarV3::Event::ExtendedProperties.new
      private_hash = {
        'source' => 'mobilis_reservation',
        'reservation_id' => reservation.id.to_s
      }
      extended_props.private = private_hash
      Rails.logger.info "🔄 ExtendedProperties created: #{extended_props.inspect}"
      
      # EventDateTimeを構築
      start_time_str = reservation.start_time.iso8601
      end_time_str = reservation.end_time.iso8601
      Rails.logger.info "🔄 Start time: #{start_time_str}, End time: #{end_time_str}"
      
      start_dt = Google::Apis::CalendarV3::EventDateTime.new(
        date_time: start_time_str,
        time_zone: 'Asia/Tokyo'
      )
      end_dt = Google::Apis::CalendarV3::EventDateTime.new(
        date_time: end_time_str,
        time_zone: 'Asia/Tokyo'
      )
      Rails.logger.info "🔄 EventDateTime objects created"
      
      # color_idを取得
      color_id_value = event_color_id(reservation)
      Rails.logger.info "🔄 Color ID: #{color_id_value.inspect} (#{color_id_value.class})"
      
      # Eventを構築
      event = Google::Apis::CalendarV3::Event.new(
        summary: event_summary(reservation),
        description: event_description(reservation),
        start: start_dt,
        end: end_dt,
        extended_properties: extended_props,
        color_id: color_id_value
      )
      Rails.logger.info "🔄 Event object created successfully"
      
      event
    rescue => e
      Rails.logger.error "❌ Error in build_event_from_reservation: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.first(10).join("\n")}"
      raise
    end
  end

  # イベントを予約情報で更新
  def update_event_from_reservation(event, reservation)
    event.summary = event_summary(reservation)
    event.description = event_description(reservation)
    event.start = Google::Apis::CalendarV3::EventDateTime.new(
      date_time: reservation.start_time.iso8601,
      time_zone: 'Asia/Tokyo'
    )
    event.end = Google::Apis::CalendarV3::EventDateTime.new(
      date_time: reservation.end_time.iso8601,
      time_zone: 'Asia/Tokyo'
    )
    event.color_id = event_color_id(reservation)
  end

  # イベントサマリー（タイトル）
  def event_summary(reservation)
    customer_name = reservation.user&.name || reservation.name || 'お客様'
    course_name = reservation.course || '予約'
    "#{customer_name} - #{course_name}"
  end

  # イベント説明
  def event_description(reservation)
    parts = []
    parts << "予約ID: #{reservation.id}"
    parts << "メニュー: #{reservation.course}" if reservation.course.present?
    if reservation.get_price.present?
      price = reservation.get_price
      # 数値をカンマ区切りでフォーマット
      formatted_price = price.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
      parts << "料金: ¥#{formatted_price}"
    end
    parts << "ステータス: #{reservation.status_text}" if reservation.status.present?
    parts << "メモ: #{reservation.note}" if reservation.note.present?
    parts.join("\n")
  end

  # イベントの色ID（ステータスに応じて）
  def event_color_id(reservation)
    status_str = reservation.status.to_s.downcase
    case status_str
    when 'confirmed'
      '10' # 緑
    when 'tentative'
      '5'  # 黄色
    when 'cancelled'
      '8'  # グレー
    when 'completed'
      '11' # オレンジ
    else
      '1'  # ラベンダー
    end
  rescue => e
    Rails.logger.error "❌ Error in event_color_id: #{e.message}"
    Rails.logger.error "❌ Reservation status: #{reservation.status.inspect} (#{reservation.status.class})"
    '1' # デフォルトの色
  end

  # Googleカレンダーイベントから予約を作成
  def create_reservation_from_event(event)
    return nil if event.start.date_time.nil?

    # 既にこのイベントIDで予約が存在する場合はスキップ
    return nil if Reservation.exists?(google_calendar_event_id: event.id)
    
    # extended_propertiesのreservation_idで既存の予約を検索
    reservation_id_from_event = event.extended_properties&.private&.dig('reservation_id')
    if reservation_id_from_event.present?
      existing_reservation = Reservation.find_by(id: reservation_id_from_event)
      if existing_reservation
        Rails.logger.info "🔄 Found existing reservation #{existing_reservation.id} by reservation_id, updating google_calendar_event_id"
        # google_calendar_event_idを更新して、既存の予約を返す
        existing_reservation.update_column(:google_calendar_event_id, event.id)
        # 時間も更新
        update_reservation_from_event(existing_reservation, event)
        return existing_reservation
      end
    end

    # イベントの説明から予約情報を抽出
    reservation_data = parse_event_description(event.description || '')
    
    # 顧客名を抽出（サマリーから）
    # フォーマット: "顧客名 - コース名" または単に "イベント名"
    summary_parts = event.summary&.split(' - ') || []
    customer_name = summary_parts.first || 'Googleカレンダーから同期'
    course_from_summary = summary_parts[1] if summary_parts.length > 1

    # 電話番号とメールアドレスを取得
    phone_number = reservation_data[:phone]
    email = reservation_data[:email]&.strip&.downcase

    # 既存のユーザーを検索（名前、電話番号、メールアドレスでマッチング）
    user = find_or_match_user(
      name: customer_name,
      phone_number: phone_number,
      email: email
    )

    # 終了時間を計算
    start_time = event.start.date_time
    end_time = event.end&.date_time
    
    # 終了時間がnil、または開始時間と同じ/以前の場合は、デフォルトで60分後を設定
    if end_time.nil? || end_time <= start_time
      end_time = start_time + 60.minutes
      Rails.logger.info "⚠️ Google Calendar event has invalid end time, using default 60 minutes: #{event.id}"
    end
    
    # 予約時間からメニューの長さを推定
    duration_minutes = ((end_time - start_time) / 60).to_i
    
    # 時間が0分以下の場合は、デフォルトで60分を設定
    if duration_minutes <= 0
      duration_minutes = 60
      end_time = start_time + 60.minutes
      Rails.logger.info "⚠️ Google Calendar event has invalid duration (#{duration_minutes} minutes), using default 60 minutes: #{event.id}"
    end

    # コース名を決定（説明から抽出、またはサマリーから、または時間から推定）
    course_name = reservation_data[:course] || course_from_summary
    
    # コース名が未設定の場合は、時間から推定
    if course_name.blank? || course_name == 'Googleカレンダーから同期'
      if duration_minutes == 60
        course_name = '対面セッション（スタジオ／出張）'
      elsif duration_minutes == 30
        course_name = 'オンライン身体分析・設計'
      elsif duration_minutes == 40
        course_name = '40分コース'
      elsif duration_minutes == 80
        course_name = '80分コース'
      else
        course_name = "#{duration_minutes}分コース"
      end
    end

    # 予約を作成
    # userが存在する場合はnameを設定しない（user.nameを優先）
    reservation_attributes = {
      user: user,
      course: course_name,
      start_time: event.start.date_time,
      end_time: end_time,
      note: reservation_data[:note] || event.description || '',
      status: :confirmed,
      google_calendar_event_id: event.id,
      google_calendar_synced_at: Time.current,
      skip_business_hours_validation: true,
      skip_advance_booking_validation: true,
      skip_advance_notice_validation: true,
      skip_overlap_validation: true
    }
    # userが存在しない場合のみnameを設定
    reservation_attributes[:name] = customer_name unless user.present?
    
    reservation = Reservation.new(reservation_attributes)

    if reservation.save
      Rails.logger.info "✅ Created reservation #{reservation.id} from Google Calendar event #{event.id} (#{event.summary})"
      reservation
    else
      Rails.logger.error "❌ Failed to create reservation from Google Calendar event: #{reservation.errors.full_messages.join(', ')}"
      nil
    end
  rescue => e
    Rails.logger.error "❌ Error creating reservation from Google Calendar event: #{e.message}"
    Rails.logger.error "❌ Backtrace: #{e.backtrace.first(5).join("\n")}"
    nil
  end

  # 予約をGoogleカレンダーイベントで更新
  def update_reservation_from_event(reservation, event)
    return if event.start.date_time.nil?

    # 更新が必要かどうかをチェック
    needs_update = false
    update_attributes = {}
    
    # 時間が変更されている場合は更新
    if reservation.start_time != event.start.date_time || reservation.end_time != event.end.date_time
      needs_update = true
      update_attributes[:start_time] = event.start.date_time
      
      # 終了時間を計算
      end_time = event.end&.date_time
      if end_time.nil? || end_time <= event.start.date_time
        # 終了時間が無効な場合は、開始時間から予約時間を計算
        duration_minutes = reservation.get_duration_minutes || 60
        end_time = event.start.date_time + duration_minutes.minutes
      end
      update_attributes[:end_time] = end_time
    end
    
    # コース名が変更されている場合は更新（イベントのタイトルから抽出）
    if event.summary.present?
      summary_parts = event.summary.split(' - ')
      course_from_summary = summary_parts[1] if summary_parts.length > 1
      
      # コース名が抽出できた場合、または時間から推定できる場合
      if course_from_summary.present? && course_from_summary != reservation.course
        needs_update = true
        update_attributes[:course] = course_from_summary
      elsif course_from_summary.blank?
        # 時間からコース名を推定
        start_time = event.start.date_time
        end_time = update_attributes[:end_time] || event.end&.date_time || (start_time + 60.minutes)
        duration_minutes = ((end_time - start_time) / 60).to_i
        
        if duration_minutes > 0
          estimated_course = case duration_minutes
                            when 60 then '対面セッション（スタジオ／出張）'
                            when 30 then 'オンライン身体分析・設計'
                            when 40 then '40分コース'
                            when 80 then '80分コース'
                            else "#{duration_minutes}分コース"
                            end
          
          if estimated_course != reservation.course
            needs_update = true
            update_attributes[:course] = estimated_course
          end
        end
      end
    end
    
    # 更新が必要な場合のみ実行
    if needs_update
      update_attributes[:google_calendar_synced_at] = Time.current
      reservation.update_columns(update_attributes)
      Rails.logger.info "✅ Updated reservation #{reservation.id} from Google Calendar event #{event.id}: #{update_attributes.keys.join(', ')}"
    end
  end

  # イベント説明から予約情報を抽出
  def parse_event_description(description)
    data = {}
    description.split("\n").each do |line|
      case line
      when /予約ID:\s*(.+)/ then data[:reservation_id] = $1.strip
      when /メニュー:\s*(.+)/ then data[:course] = $1.strip
      when /料金:\s*(.+)/ then data[:price] = $1.strip
      when /ステータス:\s*(.+)/ then data[:status] = $1.strip
      when /メモ:\s*(.+)/ then data[:note] = $1.strip
      when /電話:\s*(.+)/ then data[:phone] = $1.strip
      when /メール:\s*(.+)/ then data[:email] = $1.strip
      when /電話番号:\s*(.+)/ then data[:phone] = $1.strip
      when /Email:\s*(.+)/i then data[:email] = $1.strip
      when /E-mail:\s*(.+)/i then data[:email] = $1.strip
      end
    end
    data
  end

  # 既存のユーザーを検索または作成（名前、電話番号、メールアドレスでマッチング）
  def find_or_match_user(name:, phone_number: nil, email: nil)
    # 名前を正規化
    normalized_name = normalize_name(name)
    
    # 1. 電話番号で検索（最も確実）
    if phone_number.present?
      normalized_phone = normalize_phone(phone_number)
      user = User.where("REPLACE(REPLACE(REPLACE(phone_number, '-', ''), '(', ''), ')', '') = ?", 
                        normalized_phone.gsub(/[-\s()]/, '')).first
      if user
        Rails.logger.info "✅ Matched user by phone number: #{user.name} (ID: #{user.id})"
        # 名前が異なる場合は更新
        if normalize_name(user.name) != normalized_name && name.present?
          user.update(name: name)
          Rails.logger.info "✅ Updated user name: #{user.name} -> #{name}"
        end
        return user
      end
    end

    # 2. メールアドレスで検索
    if email.present?
      user = User.where("LOWER(email) = ?", email.downcase).first
      if user
        Rails.logger.info "✅ Matched user by email: #{user.name} (ID: #{user.id})"
        # 名前が異なる場合は更新
        if normalize_name(user.name) != normalized_name && name.present?
          user.update(name: name)
          Rails.logger.info "✅ Updated user name: #{user.name} -> #{name}"
        end
        return user
      end
    end

    # 3. 名前で完全一致検索（大文字小文字を無視）
    user = User.where("LOWER(TRIM(name)) = ?", name.strip.downcase).first
    if user
      Rails.logger.info "✅ Matched user by exact name (case-insensitive): #{user.name} (ID: #{user.id})"
      return user
    end

    # 4. 名前で正規化後の一致検索
    User.all.each do |u|
      if normalize_name(u.name) == normalized_name
        Rails.logger.info "✅ Matched user by normalized name: #{u.name} (ID: #{u.id})"
        return u
      end
    end

    # 5. 名前で部分一致検索（類似度が高い場合）
    User.all.each do |u|
      normalized_existing = normalize_name(u.name)
      # 名前が完全に含まれている、または既存の名前が含まれている場合
      if normalized_name.include?(normalized_existing) || normalized_existing.include?(normalized_name)
        # 長さが近い場合のみマッチ（短い名前の誤マッチを防ぐ）
        length_diff = (normalized_name.length - normalized_existing.length).abs
        if length_diff <= 2 && normalized_name.length >= 2 && normalized_existing.length >= 2
          Rails.logger.info "✅ Matched user by partial name: #{u.name} (ID: #{u.id})"
          return u
        end
      end
    end

    # 6. 見つからない場合は新規作成
    Rails.logger.info "📝 Creating new user: #{name}"
    User.create!(
      name: name,
      phone_number: phone_number || '',
      email: email || ''
    )
  end

  # 名前を正規化（スペース削除、全角半角統一など）
  def normalize_name(name)
    return '' if name.blank?
    
    # スペース、タブ、改行を削除
    normalized = name.strip.gsub(/[\s\t\n\r]/, '')
    
    # 全角数字を半角に変換
    normalized = normalized.tr('０-９', '0-9')
    
    # 全角英字を半角に変換
    normalized = normalized.tr('Ａ-Ｚａ-ｚ', 'A-Za-z')
    
    # 大文字小文字を統一（小文字に変換）
    normalized = normalized.downcase
    
    normalized
  end

  # 電話番号を正規化（ハイフン、括弧、スペースを削除）
  def normalize_phone(phone)
    return '' if phone.blank?
    
    # ハイフン、括弧、スペース、ドットを削除
    phone.gsub(/[-\s()\.]/, '')
  end
end

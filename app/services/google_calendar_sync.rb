# app/services/google_calendar_sync.rb
# Googleカレンダーとの双方向同期サービス

require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'

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

  # Googleカレンダーのイベントを予約として同期
  def sync_events_to_reservations(start_time: Time.current.beginning_of_day, end_time: 30.days.from_now.end_of_day)
    return unless authorized?

    events = fetch_events(start_time: start_time, end_time: end_time)
    synced_count = 0
    created_count = 0
    updated_count = 0

    events.each do |event|
      next if event.start.date_time.nil? # 終日イベントはスキップ
      next unless event.extended_properties&.private&.dig('source') == 'mobilis_reservation'

      # 既存の予約を検索（GoogleカレンダーイベントIDで）
      reservation = Reservation.find_by(google_calendar_event_id: event.id)

      if reservation
        # 更新
        update_reservation_from_event(reservation, event)
        updated_count += 1
      else
        # 新規作成（Googleカレンダーから作成された予約）
        reservation = create_reservation_from_event(event)
        created_count += 1 if reservation
      end
      synced_count += 1
    end

    Rails.logger.info "✅ Google Calendar sync completed: #{synced_count} events processed (#{created_count} created, #{updated_count} updated)"
    { synced: synced_count, created: created_count, updated: updated_count }
  end

  # 認証済みかチェック
  def authorized?
    @service.authorization.present?
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
  def self.get_authorization_url
    return nil unless File.exist?(Rails.root.join('config', 'google_calendar_credentials.json'))
    
    client_id = Google::Auth::ClientId.from_file(Rails.root.join('config', 'google_calendar_credentials.json'))
    # データベースにトークンが存在する場合はデータベースストアを使用、なければファイルストアを使用（後方互換性）
    token_store = if GoogleCalendarToken.exists?(user_id: 'default')
      GoogleAuthStores::DatabaseTokenStore.new
    else
      Google::Auth::Stores::FileTokenStore.new(file: Rails.root.join('config', 'google_calendar_token.yaml'))
    end
    authorizer = Google::Auth::UserAuthorizer.new(client_id, Google::Apis::CalendarV3::AUTH_CALENDAR, token_store)
    
    authorizer.get_authorization_url(base_url: 'urn:ietf:wg:oauth:2.0:oob')
  rescue => e
    Rails.logger.error "❌ Failed to get authorization URL: #{e.message}"
    nil
  end

  # 認証コードからトークンを取得
  def self.authorize_with_code(code)
    return nil unless File.exist?(Rails.root.join('config', 'google_calendar_credentials.json'))
    
    client_id = Google::Auth::ClientId.from_file(Rails.root.join('config', 'google_calendar_credentials.json'))
    # 認証時は常にデータベースストアを使用（新しいトークンはデータベースに保存）
    token_store = GoogleAuthStores::DatabaseTokenStore.new
    authorizer = Google::Auth::UserAuthorizer.new(client_id, Google::Apis::CalendarV3::AUTH_CALENDAR, token_store)
    
    user_id = 'default'
    credentials = authorizer.get_and_store_credentials_from_code(user_id: user_id, code: code, base_url: 'urn:ietf:wg:oauth:2.0:oob')
    
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

    # イベントの説明から予約情報を抽出
    reservation_data = parse_event_description(event.description || '')
    
    # 顧客名を抽出（サマリーから）
    customer_name = event.summary&.split(' - ')&.first || 'Googleカレンダーから同期'

    # ユーザーを検索または作成
    user = User.find_or_create_by(name: customer_name) do |u|
      u.phone_number = reservation_data[:phone] || ''
      u.email = reservation_data[:email] || ''
    end

    # 予約を作成
    reservation = Reservation.new(
      user: user,
      name: customer_name,
      course: reservation_data[:course] || 'Googleカレンダーから同期',
      start_time: event.start.date_time,
      end_time: event.end.date_time,
      note: reservation_data[:note] || event.description,
      status: :confirmed,
      google_calendar_event_id: event.id,
      google_calendar_synced_at: Time.current,
      skip_business_hours_validation: true,
      skip_advance_booking_validation: true,
      skip_advance_notice_validation: true,
      skip_overlap_validation: true
    )

    if reservation.save
      Rails.logger.info "✅ Created reservation #{reservation.id} from Google Calendar event #{event.id}"
      reservation
    else
      Rails.logger.error "❌ Failed to create reservation from Google Calendar event: #{reservation.errors.full_messages.join(', ')}"
      nil
    end
  rescue => e
    Rails.logger.error "❌ Error creating reservation from Google Calendar event: #{e.message}"
    nil
  end

  # 予約をGoogleカレンダーイベントで更新
  def update_reservation_from_event(reservation, event)
    return if event.start.date_time.nil?

    # 時間が変更されている場合は更新
    if reservation.start_time != event.start.date_time || reservation.end_time != event.end.date_time
      reservation.update_columns(
        start_time: event.start.date_time,
        end_time: event.end.date_time,
        google_calendar_synced_at: Time.current
      )
      Rails.logger.info "✅ Updated reservation #{reservation.id} from Google Calendar event #{event.id}"
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
      end
    end
    data
  end
end


# app/controllers/public/bookings_controller.rb の修正版

class Public::BookingsController < ApplicationController
  GOOGLE_CALENDAR_AVAILABILITY_CACHE_TTL = 10.minutes
  BOOKING_CREATION_LOCK_KEY = 1_492_024_001
  BOOKING_CREATION_MUTEX = Mutex.new

  # 認証をスキップ（一般ユーザー向けページのため）
  skip_before_action :verify_authenticity_token, only: [:available_times, :week_calendar]
  
  def new
    @reservation = Reservation.new
    @courses = load_courses
    
    # システム設定を取得
    @settings = ApplicationSetting.current
    
    # 🆕 LINEユーザーの場合は情報を事前入力
    if params[:line_user_id].present?
      user = User.find_by(line_user_id: params[:line_user_id])
      if user
        @user_info = {
          name: user.name,
          phone_number: user.phone_number,
          email: user.email,
          address: user.address
        }
      end
    end
  end

  # 空き時間取得用のAPIエンドポイント
  def available_times
    date = Date.parse(params[:date])
    duration = params[:duration].to_i
    
    available_slots = get_available_time_slots(date, duration)
    
    render json: {
      success: true,
      slots: available_slots.map { |slot| {
        time: slot[:start_time].strftime('%H:%M'),
        display: "#{slot[:start_time].strftime('%H:%M')} - #{slot[:end_time].strftime('%H:%M')}",
        value: slot[:start_time].strftime('%H:%M'),
        start_datetime: slot[:start_time].iso8601,
        end_datetime: slot[:end_time].iso8601
      }}
    }
  rescue => e
    render json: { success: false, error: e.message }
  end

  # 週間カレンダー用のAPIエンドポイント
  def week_calendar
    start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.current.beginning_of_week(:monday)
    duration = params[:duration].to_i
    
    settings = ApplicationSetting.current
    week_data = {}
    now = Time.current
    
    (0..6).each do |day_offset|
      date = start_date + day_offset.days
      
      # 過去の日付でもデータは含める（スロットは空）
      if date < Date.current
        week_data[date.iso8601] = {
          date: date.iso8601,
          day_name: date.strftime('%a'),
          day_number: date.day,
          slots: []
        }
        next
      end
      
      available_slots = get_available_time_slots(date, duration)
      
      # get_available_time_slots内で最低予約時間の制約を考慮しているため、
      # ここでは追加のフィルタリングは不要
      
      week_data[date.iso8601] = {
        date: date.iso8601,
        day_name: date.strftime('%a'),
        day_number: date.day,
        slots: available_slots.map { |slot| {
          time: slot[:start_time].strftime('%H:%M'),
          display: slot[:start_time].strftime('%H:%M'),
          start_datetime: slot[:start_time].iso8601,
          end_datetime: slot[:end_time].iso8601
        }}
      }
    end
    
    render json: {
      success: true,
      week_start: start_date.iso8601,
      week_data: week_data,
      settings: {
        business_hours_start: settings.business_hours_start,
        business_hours_end: settings.business_hours_end,
        slot_interval_minutes: settings.slot_interval_minutes
      }
    }
  rescue => e
    render json: { success: false, error: e.message }
  end

  def create
    @courses = load_courses
    
    Rails.logger.info "📝 Booking creation started"
    Rails.logger.info "📝 Params: #{params.inspect}"
    Rails.logger.info "📝 Booking params: #{booking_params.inspect}"
    
    begin
      unless booking_email_valid?
        flash[:alert] = '有効なメールアドレスを入力してください。 / Please enter a valid email address.'
        @reservation = Reservation.new
        return render :new, status: :unprocessable_entity
      end

    @user = find_or_create_user
      
      unless @user.persisted?
        Rails.logger.error "❌ User creation failed: #{@user.errors.full_messages.join(', ')}"
        flash[:alert] = "ユーザー情報の登録に失敗しました: #{@user.errors.full_messages.join(', ')}"
        @reservation = Reservation.new
        return render :new, status: :unprocessable_entity
      end

      Rails.logger.info "✅ User found/created: #{@user.id} (#{@user.name})"

    @reservation = build_reservation(@user)
      
      Rails.logger.info "📝 Reservation built: start_time=#{@reservation.start_time}, end_time=#{@reservation.end_time}, course=#{@reservation.course}"
      
      # 必須項目のチェック
      unless @reservation.start_time.present? && @reservation.end_time.present?
        Rails.logger.error "❌ Missing reservation time: start_time=#{@reservation.start_time}, end_time=#{@reservation.end_time}"
        flash[:alert] = '予約日時が選択されていません。カレンダーから日時を選択してください。'
        @reservation = Reservation.new
        return render :new, status: :unprocessable_entity
      end
    
    booking_result = serialize_booking_creation do
      # The availability shown in the browser can become stale. Recheck both
      # reservations and Google Calendar while holding one cross-process lock.
      if time_conflict_exists?(@reservation)
        :reservation_conflict
      else
        google_status = google_calendar_booking_status(@reservation)

        if google_status == :conflict
          :google_conflict
        elsif google_status == :unavailable
          :google_unavailable
        elsif @reservation.save
          :created
        else
          :invalid
        end
      end
    end

    case booking_result
    when :reservation_conflict
      Rails.logger.error "❌ Time conflict detected"
      flash[:alert] = '選択された時間は既に予約が入っています。別の時間をお選びください。'
      @reservation = Reservation.new
      render :new, status: :unprocessable_entity
    when :google_conflict
      Rails.logger.error "❌ Google Calendar conflict detected"
      flash[:alert] = '選択された時間は既に予定が入っています。別の時間をお選びください。'
      @reservation = Reservation.new
      render :new, status: :unprocessable_entity
    when :google_unavailable
      Rails.logger.error "❌ Booking rejected because Google Calendar could not be checked"
      flash[:alert] = '現在カレンダーを確認できません。恐れ入りますが、少し時間をおいて再度お試しください。'
      @reservation = Reservation.new
      render :new, status: :service_unavailable
    when :created
      Rails.logger.info "✅ Reservation created successfully: #{@reservation.id}"
      send_booking_notification(@reservation) if @reservation.user.line_user_id
      notify_admin(@reservation)
      redirect_to public_booking_path(@reservation),
                  notice: 'ご予約リクエストを承りました。確認のご連絡をお待ちください。'
    else
      Rails.logger.error "❌ Reservation save failed: #{@reservation.errors.full_messages.join(', ')}"
      flash[:alert] = "予約の作成に失敗しました: #{@reservation.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
    rescue => e
      Rails.logger.error "❌ Booking creation error: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.first(10).join("\n")}"
      flash[:alert] = "予約の作成中にエラーが発生しました: #{e.message}"
      @reservation = Reservation.new
      render :new, status: :unprocessable_entity
    end
  end

  def show
    begin
      @reservation = Reservation.find_by(id: params[:id])
      
      unless @reservation
        flash[:alert] = '予約が見つかりませんでした。'
        redirect_to new_public_booking_path
        return
      end
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "❌ Reservation not found: #{e.message}"
      flash[:alert] = '予約が見つかりませんでした。'
      redirect_to new_public_booking_path
    rescue => e
      Rails.logger.error "❌ Error loading reservation: #{e.class.name}: #{e.message}"
      Rails.logger.error "❌ Backtrace: #{e.backtrace.first(10).join("\n")}"
      # エラーハンドリングモジュールに任せず、直接エラーを表示
      flash[:alert] = "予約情報の読み込み中にエラーが発生しました: #{e.message}"
      redirect_to new_public_booking_path
    end
  end

  def cancel
    @reservation = Reservation.find(params[:id])
    
    if @reservation.cancellable?
      @reservation.cancel!('お客様都合によるキャンセル')
      
      # LINE通知
      send_cancellation_notification(@reservation) if @reservation.user.line_user_id
      
      redirect_to public_booking_path(@reservation), 
                  notice: 'ご予約をキャンセルいたしました。'
    else
      redirect_to public_booking_path(@reservation), 
                  alert: 'この予約はキャンセルできません。'
    end
  end

  private

  def serialize_booking_creation(&block)
    if ActiveRecord::Base.connection.adapter_name.downcase.include?("postgres")
      Reservation.transaction do
        # Transaction-scoped advisory locks work across every Heroku web dyno.
        ActiveRecord::Base.connection.select_value(
          "SELECT pg_advisory_xact_lock(#{BOOKING_CREATION_LOCK_KEY})"
        )
        yield
      end
    else
      # SQLite is used in development and test, where a process lock provides
      # equivalent serialization without PostgreSQL-specific SQL.
      BOOKING_CREATION_MUTEX.synchronize do
        Reservation.transaction(&block)
      end
    end
  end

  # 空き時間スロットを取得
  def get_available_time_slots(date, duration)
    settings = ApplicationSetting.current
    
    # 週間スケジュールを取得（その日の週の開始日を計算）
    # アドミン側では日曜日を週の開始日として使用しているため、日曜日で計算
    week_start = date.beginning_of_week(:sunday)
    weekly_schedule = WeeklySchedule.find_by(week_start_date: week_start)
    
    # 日曜日で見つからない場合は、月曜日もチェック（後方互換性のため）
    if !weekly_schedule
      week_start_monday = date.beginning_of_week(:monday)
      weekly_schedule = WeeklySchedule.find_by(week_start_date: week_start_monday)
      week_start = week_start_monday if weekly_schedule
    end
    
    # その日の曜日を取得（0=日曜日, 1=月曜日, ..., 6=土曜日）
    day_of_week = date.wday
    
    # 週間スケジュールからその日の営業時間を取得
    if weekly_schedule && weekly_schedule.schedule.present?
      schedule_data = weekly_schedule.schedule_for_javascript
      day_schedule = schedule_data[day_of_week]
      
      # デバッグ: スケジュールデータをログ出力
      Rails.logger.info "📅 Weekly schedule data for #{date} (day_of_week: #{day_of_week}): #{day_schedule.inspect}"
      Rails.logger.info "📅 Raw schedule for week #{week_start}: #{weekly_schedule.schedule.inspect}"
      
      # schedule_for_javascriptが返すデータは { enabled: ..., times: ... } の形式
      # enabledの値を取得（シンボルキーと文字列キーの両方をチェック）
      # schedule_for_javascriptメソッドは常に { enabled: ..., times: ... } の形式で返す
      enabled_value = nil
      if day_schedule
        # まずシンボルキーをチェック（schedule_for_javascriptはシンボルキーで返す）
        if day_schedule.is_a?(Hash) && day_schedule.key?(:enabled)
          enabled_value = day_schedule[:enabled]
        # 次に文字列キーをチェック（JSONから復元された場合）
        elsif day_schedule.is_a?(Hash) && day_schedule.key?("enabled")
          enabled_value = day_schedule["enabled"]
        # ハッシュではなく、メソッドでアクセスできる場合（ActiveSupport::HashWithIndifferentAccessなど）
        elsif day_schedule.respond_to?(:enabled)
          enabled_value = day_schedule.enabled
        # キーが存在しない場合はデフォルトでtrue（schedule_for_javascriptの仕様）
        else
          enabled_value = true
        end
      end
      
      Rails.logger.info "📅 Enabled value for #{date}: #{enabled_value.inspect} (type: #{enabled_value.class})"
      Rails.logger.info "📅 day_schedule class: #{day_schedule.class if day_schedule}"
      Rails.logger.info "📅 day_schedule keys: #{day_schedule.keys.inspect if day_schedule.is_a?(Hash)}"
      
      # その日が無効（enabled: false）の場合は、予約不可として空配列を返す
      # enabledがfalse、nil以外のfalse値、または文字列"false"の場合もチェック
      # 注意: false == false は true なので、== で比較可能
      if enabled_value === false || enabled_value == "false" || enabled_value == false.to_s
        Rails.logger.info "🚫 Date #{date} is disabled in weekly schedule (enabled: #{enabled_value}) - no slots available"
        return []
      end
      
      # enabledがtrueで、timesが存在する場合のみ週間スケジュールの営業時間を使用
      time_slots = []
      if day_schedule && day_schedule.is_a?(Hash) && enabled_value != false && enabled_value != "false" && enabled_value != false.to_s
        times_data = day_schedule[:times] || day_schedule["times"]
        if times_data.present? && times_data.is_a?(Array)
          # 週間スケジュールのすべての時間スロットを使用
          times_data.each do |time_slot|
            start_time_str = time_slot[:start] || time_slot["start"]
            end_time_str = time_slot[:end] || time_slot["end"]
            if start_time_str && end_time_str
              opening_time = Time.zone.parse("#{date} #{start_time_str}")
              closing_time = Time.zone.parse("#{date} #{end_time_str}")
              time_slots << { opening: opening_time, closing: closing_time }
              Rails.logger.info "📅 Using weekly schedule slot for #{date}: #{start_time_str} - #{end_time_str}"
            end
          end
        end
      end
      
      # 時間スロットがない場合は、システム設定を使用
      if time_slots.empty?
        opening_time = Time.zone.parse("#{date} #{settings.business_hours_start}:00")
        closing_time = Time.zone.parse("#{date} #{settings.business_hours_end}:00")
        time_slots << { opening: opening_time, closing: closing_time }
        Rails.logger.info "📅 Using system settings for #{date}: #{settings.business_hours_start}:00 - #{settings.business_hours_end}:00"
      end
    else
      # 週間スケジュールがない場合は、システム設定を使用
      opening_time = Time.zone.parse("#{date} #{settings.business_hours_start}:00")
      closing_time = Time.zone.parse("#{date} #{settings.business_hours_end}:00")
      time_slots = [{ opening: opening_time, closing: closing_time }]
      Rails.logger.debug "📅 No weekly schedule found, using system settings for #{date}"
    end
    
    # インターバル時間を取得
    interval_minutes = settings.reservation_interval_minutes
    
    # 最低予約時間を取得（デフォルト2時間）
    min_advance_hours = settings.min_advance_booking_hours || 2
    min_advance_time = Time.current + min_advance_hours.hours
    
    # スロット間隔を取得
    slot_interval = settings.slot_interval_minutes.minutes
    available_slots = []
    
    # デバッグ: その日の既存予約を確認（タイムゾーンを考慮）
    date_start = date.beginning_of_day.in_time_zone
    date_end = date.end_of_day.in_time_zone
    existing_reservations = Reservation.active.where(
      'start_time >= ? AND start_time <= ?',
      date_start, date_end
    )
    Rails.logger.debug "📋 Existing reservations for #{date}: #{existing_reservations.count}"
    existing_reservations.each do |res|
      Rails.logger.debug "  - #{res.start_time.strftime('%Y-%m-%d %H:%M')} - #{res.end_time.strftime('%H:%M')} (status: #{res.status}, course: #{res.course})"
    end

    google_busy_periods = google_calendar_busy_periods_for(date)

    # When Google Calendar integration is enabled, failing to check the
    # calendar must not expose every slot as available and cause double
    # bookings. Return no slots and let the customer retry shortly.
    if google_calendar_enabled? && google_busy_periods.nil?
      Rails.logger.error "❌ Availability hidden because Google Calendar could not be checked for #{date}"
      return []
    end
    
    # 各時間スロットごとに利用可能な時間を生成
    time_slots.each do |time_slot|
      opening_time = time_slot[:opening]
      closing_time = time_slot[:closing]
    
    current_time = opening_time
    while current_time + duration.minutes <= closing_time
      end_time = current_time + duration.minutes
      
        # 最低予約時間の制約をチェック（今日の日付の場合のみ）
        if date == Date.current && current_time < min_advance_time
          current_time += slot_interval
          next
        end
        
        # インターバルを考慮した空きチェック
        if time_slot_available_with_interval?(current_time, end_time, interval_minutes) &&
           google_calendar_slot_available?(current_time, end_time, interval_minutes, google_busy_periods)
        available_slots << {
          start_time: current_time,
          end_time: end_time,
            interval_info: "（#{interval_minutes}分準備時間含む）"
        }
      end
      
      current_time += slot_interval
      end
    end
    
    Rails.logger.info "✅ Available slots for #{date}: #{available_slots.count}"
    Rails.logger.info "📋 Available slot times for #{date}: #{available_slots.map { |s| "#{s[:start_time].strftime('%H:%M')}-#{s[:end_time].strftime('%H:%M')}" }.join(', ')}"
    available_slots
  end

  def google_calendar_enabled?
    ENV['GOOGLE_CALENDAR_SYNC_ENABLED'] == 'true'
  end

  def google_calendar_busy_periods_for(date)
    return [] unless google_calendar_enabled?

    cache_key = google_calendar_cache_key(date)
    @google_calendar_sync ||= GoogleCalendarSync.new
    busy_periods = @google_calendar_sync.busy_periods(
      start_time: date.beginning_of_day.in_time_zone,
      end_time: date.end_of_day.in_time_zone
    )

    if busy_periods.nil?
      cached_periods = google_calendar_cache.read(cache_key)
      unless cached_periods.nil?
        Rails.logger.warn "⚠️ Using cached Google Calendar availability for #{date}"
        return cached_periods
      end

      return nil
    end

    google_calendar_cache.write(
      cache_key,
      busy_periods,
      expires_in: GOOGLE_CALENDAR_AVAILABILITY_CACHE_TTL
    )
    busy_periods
  rescue => e
    Rails.logger.error "❌ Google Calendar availability check failed for #{date}: #{e.message}"
    cached_periods = google_calendar_cache.read(google_calendar_cache_key(date))
    return cached_periods unless cached_periods.nil?

    nil
  end

  def google_calendar_booking_status(reservation)
    return :available unless google_calendar_enabled?

    interval_minutes = google_calendar_interval_minutes
    @google_calendar_sync ||= GoogleCalendarSync.new
    busy_periods = @google_calendar_sync.busy_periods(
      start_time: reservation.start_time - interval_minutes.minutes,
      end_time: reservation.end_time + interval_minutes.minutes
    )
    return :unavailable if busy_periods.nil?

    google_calendar_slot_available?(
      reservation.start_time,
      reservation.end_time,
      interval_minutes,
      busy_periods
    ) ? :available : :conflict
  rescue => e
    Rails.logger.error "❌ Final Google Calendar booking check failed: #{e.message}"
    :unavailable
  end

  def google_calendar_interval_minutes
    ApplicationSetting.current.reservation_interval_minutes
  end

  def google_calendar_cache
    Rails.cache
  end

  def google_calendar_cache_key(date)
    "google_calendar/busy_periods/#{date.iso8601}"
  end

  def google_calendar_slot_available?(start_time, end_time, interval_minutes, busy_periods)
    return true if busy_periods.blank?

    interval_start = start_time - interval_minutes.minutes
    interval_end = end_time + interval_minutes.minutes

    busy_periods.none? do |period|
      period[:start_time] < interval_end && period[:end_time] > interval_start
    end
  end

  def time_slot_available_with_interval?(start_time, end_time, interval_minutes = nil)
    interval_minutes ||= ApplicationSetting.current.reservation_interval_minutes
    
    # インターバルを考慮した重複チェック
    # start_time - interval_minutes分 から end_time + interval_minutes分 の範囲で重複をチェック
    interval_start = start_time - interval_minutes.minutes
    interval_end = end_time + interval_minutes.minutes
    
    Rails.logger.info "🔍 Checking availability: #{start_time.strftime('%Y-%m-%d %H:%M')} - #{end_time.strftime('%H:%M')} (interval: #{interval_minutes}min, range: #{interval_start.strftime('%Y-%m-%d %H:%M')} - #{interval_end.strftime('%Y-%m-%d %H:%M')})"
    
    # まず、時間的に重複する可能性のある予約をSQLで絞り込む（パフォーマンス向上）
    # 個別インターバル時間が設定されている可能性があるため、広めに範囲を取る（最大120分と仮定）
    extended_start = interval_start - 120.minutes
    extended_end = interval_end + 120.minutes
    
    # 時間的に重複する可能性のある予約を取得（キャンセルされていないもの）
    # 注意: SQLの条件は「予約の終了時間が範囲の開始より後」かつ「予約の開始時間が範囲の終了より前」
    candidate_reservations = Reservation.active.where(
      'end_time > ? AND start_time < ?',
      extended_start, extended_end
    )
    
    Rails.logger.info "🔍 Found #{candidate_reservations.count} candidate reservations in extended range (#{extended_start.strftime('%Y-%m-%d %H:%M')} - #{extended_end.strftime('%Y-%m-%d %H:%M')})"
    
    # 候補予約の詳細をログ出力
    candidate_reservations.each do |res|
      Rails.logger.info "  - Candidate: ID=#{res.id}, #{res.start_time.strftime('%Y-%m-%d %H:%M')} - #{res.end_time.strftime('%H:%M')} (status: #{res.status})"
    end
    
    # 各予約の個別インターバル時間を考慮して、実際に重複しているかチェック
    overlapping_reservations = candidate_reservations.select do |res|
      # 各予約の有効なインターバル時間を取得
      res_interval = res.effective_interval_minutes
      
      # タイムゾーンを考慮して予約時間を取得
      res_start = res.start_time.in_time_zone
      res_end = res.end_time.in_time_zone
      
      # 予約の開始時間からインターバル分前
      res_interval_start = res_start - res_interval.minutes
      # 予約の終了時間からインターバル分後
      res_interval_end = res_end + res_interval.minutes
      
      # 時間帯が重複しているかチェック
      overlaps = res_interval_start < interval_end && res_interval_end > interval_start
      
      if overlaps
        Rails.logger.info "  ⚠️ Overlap detected: Reservation ID=#{res.id}, #{res_start.strftime('%Y-%m-%d %H:%M %Z')} - #{res_end.strftime('%H:%M %Z')} (status: #{res.status}, interval: #{res_interval}min, range: #{res_interval_start.strftime('%Y-%m-%d %H:%M %Z')} - #{res_interval_end.strftime('%Y-%m-%d %H:%M %Z')})"
        Rails.logger.info "  ⚠️ Checking slot: #{start_time.strftime('%Y-%m-%d %H:%M %Z')} - #{end_time.strftime('%H:%M %Z')} (range: #{interval_start.strftime('%Y-%m-%d %H:%M %Z')} - #{interval_end.strftime('%Y-%m-%d %H:%M %Z')})"
      end
      
      overlaps
    end
    
    # デバッグログ
    if overlapping_reservations.any?
      Rails.logger.info "⚠️ Time slot conflict detected: #{start_time.strftime('%Y-%m-%d %H:%M')} - #{end_time.strftime('%H:%M')}"
      overlapping_reservations.each do |res|
        res_interval = res.effective_interval_minutes
        Rails.logger.info "  - Existing reservation: ID=#{res.id}, #{res.start_time.strftime('%Y-%m-%d %H:%M')} - #{res.end_time.strftime('%H:%M')} (status: #{res.status}, interval: #{res_interval}min)"
      end
    else
      Rails.logger.info "✅ No conflicts found for: #{start_time.strftime('%Y-%m-%d %H:%M')} - #{end_time.strftime('%H:%M')}"
    end
    
    overlapping_reservations.empty?
  end

  # 60分+20分インターバルを考慮した空きチェック
  def time_slot_available_with_60min_interval?(start_time, end_time)
    # 60分のインターバル時間を考慮
    interval_minutes = 60
    
    # 既存の予約との重複チェック（60分インターバル考慮）
    interval_start = start_time - interval_minutes.minutes
    interval_end = end_time + interval_minutes.minutes
    
    overlapping_reservations = Reservation.active.where(
      'start_time < ? AND end_time > ?',
      interval_end, interval_start
    )
    
    overlapping_reservations.empty?
  end

  # 75分インターバルを考慮した空きチェック
  def time_slot_available_with_75min_interval?(start_time, end_time)
    # 75分のインターバル時間を考慮（次の予約の前に75分の準備時間）
    interval_minutes = 75
    
    # 既存の予約との重複チェック（次の予約の前に75分の準備時間を確保）
    interval_end = end_time + interval_minutes.minutes
    
    overlapping_reservations = Reservation.active.where(
      'start_time < ? AND end_time > ?',
      interval_end, start_time
    )
    
    overlapping_reservations.empty?
  end

  # 指定時間帯が空いているかチェック
  def time_slot_available?(start_time, end_time)
    # アクティブな予約（キャンセル以外）を検索
    overlapping_reservations = Reservation.active
      .where('start_time < ? AND end_time > ?', end_time, start_time)
    
    overlapping_reservations.empty?
  end

  # 予約時間の重複チェック
  def time_conflict_exists?(reservation)
    return false unless reservation.start_time && reservation.end_time
    
    Reservation.active
      .where.not(id: reservation.id)
      .where('start_time < ? AND end_time > ?', reservation.end_time, reservation.start_time)
      .exists?
  end

  def booking_email_valid?
    email = booking_params[:email].to_s.strip
    email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
  end

  def find_or_create_user
    phone = User.normalize_phone_number(booking_params[:phone_number])
    
    user = User.find_by(phone_number: phone)
    if user
      # Repeated bookings must keep the customer profile in sync with the
      # values submitted in the current booking form.
      user.assign_attributes(user_attributes.compact_blank)
      user.save
      return user
    end

    # 新規ユーザー作成
    User.create(user_attributes)
  end

  def build_reservation(user)
    reservation = Reservation.new
    reservation.user = user
    reservation.name = user.name
    reservation.status = :tentative  # 仮予約
    reservation.course = booking_params[:course]
    reservation.note = booking_params[:notes]
    
    # 選択された時間を解析してstart_timeとend_timeを設定
    if booking_params[:selected_datetime].present?
      reservation.start_time = Time.zone.parse(booking_params[:selected_datetime])
      duration = course_duration(reservation.course)
      reservation.end_time = reservation.start_time + duration.minutes
    end
    
    reservation
  end

  def send_booking_notification(reservation)
    LineBookingNotifier.new_booking_request(reservation)
  rescue => e
    Rails.logger.error "LINE通知エラー: #{e.message}"
  end

  def send_cancellation_notification(reservation)
    LineBookingNotifier.send_cancellation_notification(reservation)
  rescue => e
    Rails.logger.error "LINEキャンセル通知エラー: #{e.message}"
  end

  def notify_admin(reservation)
    AdminNotificationJob.perform_now(reservation)
  rescue => e
    Rails.logger.error "管理者通知エラー: #{e.message}"
  end

  def booking_params
    params.require(:booking).permit(
      :name, :phone_number, :email, :address, :building_info,
      :course, :selected_datetime, :notes, :access_notes
    )
  end

  def user_attributes
    {
      name: booking_params[:name],
      phone_number: User.normalize_phone_number(booking_params[:phone_number]),
      email: booking_params[:email],
      address: booking_params[:address]
    }
  end

  def course_duration(course)
    case course
    when '初回評価セッション' then 60
    when '対面セッション（スタジオ／出張）' then 60
    when 'オンライン身体分析・設計' then 30
    else 60
    end
  end

  def load_courses
    [
      { name: '初回評価セッション', duration: 60, price: Reservation.price_for('初回評価セッション') },
      { name: '対面セッション（スタジオ／出張）', duration: 60, price: Reservation.price_for('対面セッション（スタジオ／出張）') },
      { name: 'オンライン身体分析・設計', duration: 30, price: Reservation.price_for('オンライン身体分析・設計') }
    ]
  end
end

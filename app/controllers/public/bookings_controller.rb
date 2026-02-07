# app/controllers/public/bookings_controller.rb の修正版

class Public::BookingsController < ApplicationController
  def new
    @reservation = Reservation.new
    @courses = [
      { name: '40分コース', duration: 40, price: 8000 },
      { name: '60分コース', duration: 60, price: 12000 },
      { name: '80分コース', duration: 80, price: 16000 }
    ]
    
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
    
    # 予約時間の重複チェック
    if time_conflict_exists?(@reservation)
        Rails.logger.error "❌ Time conflict detected"
      flash[:alert] = '選択された時間は既に予約が入っています。別の時間をお選びください。'
        @reservation = Reservation.new
      return render :new, status: :unprocessable_entity
    end
    
    if @reservation.save
        Rails.logger.info "✅ Reservation created successfully: #{@reservation.id}"
      # LINE通知を送信
      send_booking_notification(@reservation) if @reservation.user.line_user_id
      
      # 管理者への通知
      notify_admin(@reservation)
      
      redirect_to public_booking_path(@reservation), 
                  notice: 'ご予約リクエストを承りました。確認のご連絡をお待ちください。'
    else
        Rails.logger.error "❌ Reservation save failed: #{@reservation.errors.full_messages.join(', ')}"
        flash[:alert] = "予約の作成に失敗しました: #{@reservation.errors.full_messages.join(', ')}"
        @reservation = Reservation.new
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
    @reservation = Reservation.find(params[:id])
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

  # 空き時間スロットを取得
  def get_available_time_slots(date, duration)
    settings = ApplicationSetting.current
    
    # 週間スケジュールを取得（その日の週の開始日を計算）
    week_start = date.beginning_of_week(:monday)
    weekly_schedule = WeeklySchedule.find_by(week_start_date: week_start)
    
    # その日の曜日を取得（0=日曜日, 1=月曜日, ..., 6=土曜日）
    day_of_week = date.wday
    
    # 週間スケジュールからその日の営業時間を取得
    if weekly_schedule && weekly_schedule.schedule.present?
      schedule_data = weekly_schedule.schedule_for_javascript
      day_schedule = schedule_data[day_of_week]
      
      if day_schedule && day_schedule[:enabled] && day_schedule[:times].present?
        # 週間スケジュールの営業時間を使用
        first_time_slot = day_schedule[:times].first
        opening_time = Time.zone.parse("#{date} #{first_time_slot[:start]}")
        closing_time = Time.zone.parse("#{date} #{first_time_slot[:end]}")
        Rails.logger.debug "📅 Using weekly schedule for #{date}: #{first_time_slot[:start]} - #{first_time_slot[:end]}"
      else
        # 週間スケジュールで無効または時間がない場合は、システム設定を使用
        opening_time = Time.zone.parse("#{date} #{settings.business_hours_start}:00")
        closing_time = Time.zone.parse("#{date} #{settings.business_hours_end}:00")
        Rails.logger.debug "📅 Using system settings for #{date}: #{settings.business_hours_start}:00 - #{settings.business_hours_end}:00"
      end
    else
      # 週間スケジュールがない場合は、システム設定を使用
      opening_time = Time.zone.parse("#{date} #{settings.business_hours_start}:00")
      closing_time = Time.zone.parse("#{date} #{settings.business_hours_end}:00")
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
    
    current_time = opening_time
    while current_time + duration.minutes <= closing_time
      end_time = current_time + duration.minutes
      
      # 最低予約時間の制約をチェック（今日の日付の場合のみ）
      if date == Date.current && current_time < min_advance_time
        current_time += slot_interval
        next
      end
      
      # インターバルを考慮した空きチェック
      if time_slot_available_with_interval?(current_time, end_time, interval_minutes)
        available_slots << {
          start_time: current_time,
          end_time: end_time,
          interval_info: "（#{interval_minutes}分準備時間含む）"
        }
      end
      
      current_time += slot_interval
    end
    
    Rails.logger.debug "✅ Available slots for #{date}: #{available_slots.count}"
    available_slots
  end

  def time_slot_available_with_interval?(start_time, end_time, interval_minutes = nil)
    interval_minutes ||= ApplicationSetting.current.reservation_interval_minutes
    
    # インターバルを考慮した重複チェック
    # start_time - interval_minutes分 から end_time + interval_minutes分 の範囲で重複をチェック
    interval_start = start_time - interval_minutes.minutes
    interval_end = end_time + interval_minutes.minutes
    
    Rails.logger.debug "🔍 Checking availability: #{start_time.strftime('%Y-%m-%d %H:%M')} - #{end_time.strftime('%H:%M')} (interval: #{interval_minutes}min, range: #{interval_start.strftime('%Y-%m-%d %H:%M')} - #{interval_end.strftime('%Y-%m-%d %H:%M')})"
    
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
    
    Rails.logger.debug "🔍 Found #{candidate_reservations.count} candidate reservations in extended range (#{extended_start.strftime('%Y-%m-%d %H:%M')} - #{extended_end.strftime('%Y-%m-%d %H:%M')})"
    
    # 各予約の個別インターバル時間を考慮して、実際に重複しているかチェック
    overlapping_reservations = candidate_reservations.select do |res|
      # 各予約の有効なインターバル時間を取得
      res_interval = res.effective_interval_minutes
      
      # 予約の開始時間からインターバル分前
      res_interval_start = res.start_time - res_interval.minutes
      # 予約の終了時間からインターバル分後
      res_interval_end = res.end_time + res_interval.minutes
      
      # 時間帯が重複しているかチェック
      overlaps = res_interval_start < interval_end && res_interval_end > interval_start
      
      if overlaps
        Rails.logger.debug "  ⚠️ Overlap detected: Reservation ID=#{res.id}, #{res.start_time.strftime('%Y-%m-%d %H:%M')} - #{res.end_time.strftime('%H:%M')} (status: #{res.status}, interval: #{res_interval}min, range: #{res_interval_start.strftime('%Y-%m-%d %H:%M')} - #{res_interval_end.strftime('%Y-%m-%d %H:%M')})"
      end
      
      overlaps
    end
    
    # デバッグログ
    if overlapping_reservations.any?
      Rails.logger.debug "⚠️ Time slot conflict detected: #{start_time.strftime('%Y-%m-%d %H:%M')} - #{end_time.strftime('%H:%M')}"
      overlapping_reservations.each do |res|
        res_interval = res.effective_interval_minutes
        Rails.logger.debug "  - Existing reservation: ID=#{res.id}, #{res.start_time.strftime('%Y-%m-%d %H:%M')} - #{res.end_time.strftime('%H:%M')} (status: #{res.status}, interval: #{res_interval}min)"
      end
    else
      Rails.logger.debug "✅ No conflicts found for: #{start_time.strftime('%Y-%m-%d %H:%M')} - #{end_time.strftime('%H:%M')}"
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

  def find_or_create_user
    phone = booking_params[:phone_number]
    
    user = User.find_by(phone_number: phone)
    return user if user

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

  def notify_admin(reservation)
    AdminNotificationJob.perform_later(reservation)
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
      phone_number: booking_params[:phone_number],
      email: booking_params[:email],
      address: booking_params[:address]
    }
  end

  def course_duration(course)
    case course
    when '40分コース' then 40
    when '60分コース' then 60
    when '80分コース' then 80
    else 60
    end
  end

  def load_courses
    [
      { name: '40分コース', duration: 40, price: 8000 },
      { name: '60分コース', duration: 60, price: 12000 },
      { name: '80分コース', duration: 80, price: 16000 }
    ]
  end
end
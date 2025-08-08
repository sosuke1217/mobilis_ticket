# app/controllers/admin/reservations_controller.rb

class Admin::ReservationsController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :set_reservation, only: [:show, :edit, :update, :destroy]

  def index
    @today_reservations = Reservation.includes(:user)
      .where(start_time: Time.current.beginning_of_day..Time.current.end_of_day)
      .where.not(status: :cancelled)
      .order(:start_time)
    
    respond_to do |format|
      format.html
      format.json do
        if request.format.json?
          Rails.logger.info "🔍 JSON request received for calendar events"
          Rails.logger.info "📋 All params: #{params.inspect}"

          begin
            # システム設定を取得
            @settings = ApplicationSetting.current
            system_interval = @settings&.reservation_interval_minutes || 15
            Rails.logger.info "✅ System interval: #{system_interval} minutes"
            
            # 予約を取得（キャンセル済みは除外）
          reservations = Reservation.includes(:user)
            .where(start_time: params[:start]..params[:end])
              .where.not(status: :cancelled)
            .order(:start_time)

                      # シフトデータを取得
          begin
            Rails.logger.info "🔍 Shift params: start=#{params[:start]}, end=#{params[:end]}"
            
            if params[:start].present? && params[:end].present?
              shifts = Shift.where(date: params[:start].to_date..params[:end].to_date)
                .order(:date)
              Rails.logger.info "📋 Found #{shifts.count} shifts"
              shifts.each do |shift|
                Rails.logger.info "  - Shift #{shift.id}: #{shift.date} (#{shift.shift_type})"
              end
            else
              Rails.logger.warn "⚠️ Missing start/end params for shifts, using default range"
              shifts = Shift.where(date: Date.current..Date.current + 7.days).order(:date)
              Rails.logger.info "📋 Found #{shifts.count} shifts (default range)"
            end
          rescue => e
            Rails.logger.error "❌ Error loading shifts: #{e.message}"
            shifts = []
          end

          Rails.logger.info "📋 Found #{reservations.count} reservations"

          events = []

            # 予約イベントを生成
            reservations.each do |reservation|
              Rails.logger.info "🔍 Processing reservation ID=#{reservation.id}"
              
              # 顧客名を取得
              customer_name = reservation.name.present? ? reservation.name : reservation.user&.name || '未設定'
              
              # JST時間として処理
              start_in_jst = reservation.start_time.in_time_zone('Asia/Tokyo')
              
              # 🔧 重要：コース時間を正確に抽出
              course_duration_minutes = extract_course_duration(reservation.course)
              
              # 🔧 重要：インターバル時間を正確に取得
              # 個別設定があればそれを使用、なければシステム設定
              interval_duration_minutes = if reservation.individual_interval_minutes.present?
                reservation.individual_interval_minutes
              else
                system_interval
              end
              
              # 🔧 重要：合計時間を計算
              total_duration_minutes = course_duration_minutes + interval_duration_minutes
              
              # 🔧 重要：終了時間を開始時間から計算（DBの値は使わない）
              calculated_end_time = start_in_jst + total_duration_minutes.minutes
              
              Rails.logger.info "🕐 Complete time calculation for reservation #{reservation.id}:"
              Rails.logger.info "  course_string: '#{reservation.course}'"
              Rails.logger.info "  course_duration: #{course_duration_minutes} minutes"
              Rails.logger.info "  individual_interval: #{reservation.individual_interval_minutes || 'nil (using system)'}"
              Rails.logger.info "  interval_duration: #{interval_duration_minutes} minutes"
              Rails.logger.info "  total_duration: #{total_duration_minutes} minutes"
              Rails.logger.info "  start_time: #{start_in_jst}"
              Rails.logger.info "  calculated_end: #{calculated_end_time}"
              Rails.logger.info "  db_end_time: #{reservation.end_time&.in_time_zone('Asia/Tokyo')}"
              Rails.logger.info "  slots_needed: #{total_duration_minutes / 10.0} (10min intervals)"
              
              # FullCalendar用のISO文字列（タイムゾーン情報なし）
              start_iso = start_in_jst.strftime('%Y-%m-%dT%H:%M:%S')
              end_iso = calculated_end_time.strftime('%Y-%m-%dT%H:%M:%S')
              
              # インターバル情報
              has_interval = interval_duration_minutes > 0
              is_individual_interval = reservation.individual_interval_minutes.present?
              
              # ステータスに応じた色設定
              colors = get_status_colors(reservation.status)
              
              # 🎯 重要：イベントオブジェクトを作成（正確な時間データ付き）
              event = {
                id: reservation.id.to_s,
                title: "#{customer_name} - #{reservation.course}",
                start: start_iso,
                end: end_iso,  # 📅 計算された正確な終了時間
                backgroundColor: colors[:bg],
                borderColor: colors[:border],
                textColor: colors[:text] || 'white',
                classNames: build_event_classes(reservation, has_interval),
                      extendedProps: {
                  type: 'reservation',
                  customer_name: customer_name,
                  course: reservation.course,
                  course_duration: course_duration_minutes,
                  interval_duration: interval_duration_minutes,
                  total_duration: total_duration_minutes,
                  has_interval: has_interval,
                  is_individual_interval: is_individual_interval,
                  effective_interval_minutes: interval_duration_minutes,
                  individual_interval_minutes: reservation.individual_interval_minutes,
                  system_interval_minutes: system_interval,
                  status: reservation.status,
                  note: reservation.note,
                  cancellation_reason: reservation.cancellation_reason,
                  # 計算検証用
                  calculated_slots: total_duration_minutes / 10.0,
                  expected_height_px: (total_duration_minutes / 10.0) * 40,
                  customer: {
                    id: reservation.user&.id,
                    name: customer_name,
                    phone: reservation.user&.phone_number,
                    email: reservation.user&.email,
                    kana: reservation.user&.respond_to?(:kana) ? reservation.user.kana : nil,
                    birth_date: reservation.user&.birth_date&.strftime('%Y-%m-%d')
                  }
                }
              }
              
              events << event
              
              # 🎯 各コースの組み合わせをログ出力
              course_type = case course_duration_minutes
              when 40 then "40分コース"
              when 60 then "60分コース"  
              when 80 then "80分コース"
              else "不明(#{course_duration_minutes}分)"
              end
              
              interval_type = is_individual_interval ? "個別#{interval_duration_minutes}分" : "システム#{interval_duration_minutes}分"
              
              Rails.logger.info "✅ Event created: #{course_type} + #{interval_type} = #{total_duration_minutes}分 (#{total_duration_minutes/10.0}スロット)"
            end

            # シフトイベントを生成
            Rails.logger.info "🎯 Starting shift event generation for #{shifts.count} shifts"
            shifts.each do |shift|
              begin
                Rails.logger.info "🔍 Processing shift ID=#{shift.id} for date=#{shift.date}"
              
              # シフトの開始時間と終了時間を設定
              shift_start_time = if shift.start_time.present?
                shift.date.to_time.change(hour: shift.start_time.hour, min: shift.start_time.min)
              else
                shift.date.to_time.change(hour: 9, min: 0) # デフォルト9:00
              end
              
              shift_end_time = if shift.end_time.present?
                shift.date.to_time.change(hour: shift.end_time.hour, min: shift.end_time.min)
              else
                shift.date.to_time.change(hour: 18, min: 0) # デフォルト18:00
              end
              
              # シフトタイプに応じた色設定
              shift_colors = get_shift_colors(shift.shift_type)
              
              # シフトイベントを作成
              shift_event = {
                id: "shift_#{shift.id}",
                title: "#{shift.shift_type_display} - #{shift.business_hours}",
                start: shift_start_time.strftime('%Y-%m-%dT%H:%M:%S'),
                end: shift_end_time.strftime('%Y-%m-%dT%H:%M:%S'),
                backgroundColor: shift_colors[:bg],
                borderColor: shift_colors[:border],
                textColor: shift_colors[:text] || 'white',
                classNames: ['fc-timegrid-event', 'shift-event', shift.shift_type],
                extendedProps: {
                  type: 'shift',
                  shift_id: shift.id,
                  shift_type: shift.shift_type,
                  shift_type_display: shift.shift_type_display,
                  business_hours: shift.business_hours,
                  breaks: shift.breaks,
                  notes: shift.notes
                }
              }
              
              Rails.logger.info "✅ Shift event created: #{shift.shift_type_display} (#{shift.business_hours})"
              
              events << shift_event
              rescue => e
                Rails.logger.error "❌ Error processing shift #{shift.id}: #{e.message}"
                Rails.logger.error e.backtrace.first(5).join("\n")
              end
            end
            
            Rails.logger.info "🎯 Shift event generation completed. Total events: #{events.count}"
            
            # 🎯 全体のサマリーログ
            Rails.logger.info "📊 Event creation summary:"
            events.group_by { |e| e[:extendedProps][:total_duration] }.each do |duration, events_group|
              slots = duration / 10.0
              Rails.logger.info "  #{duration}分 (#{slots}スロット): #{events_group.length}件"
            end
            
            render json: events, content_type: 'application/json'

        rescue => e
          Rails.logger.error "❌ Calendar data fetch error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: {
              error: 'カレンダーデータの取得に失敗しました',
              details: e.message,
              backtrace: Rails.env.development? ? e.backtrace.first(5) : nil
          }, status: :internal_server_error
          end
        else
          render json: { error: 'Invalid request format' }, status: :bad_request
        end
      end
    end
  end

  def calendar
    # カレンダーページを表示
  end

  def show
      respond_to do |format|
      format.html
      format.json do
          render json: {
            success: true,
            id: @reservation.id,
          start_time: @reservation.start_time.in_time_zone('Asia/Tokyo').iso8601,  # JST時間で送信
          end_time: @reservation.end_time.in_time_zone('Asia/Tokyo').iso8601,      # JST時間で送信
            course: @reservation.course,
            status: @reservation.status,
            note: @reservation.note,
          user_id: @reservation.user_id,
          user: {
            id: @reservation.user&.id,
            name: @reservation.user&.name,
            kana: @reservation.user&.respond_to?(:kana) ? @reservation.user.kana : nil,
            phone: @reservation.user&.phone_number,
            email: @reservation.user&.email,
            birth_date: @reservation.user&.birth_date&.strftime('%Y-%m-%d')
          }
        }
      end
    end
  end

  def new
    @reservation = Reservation.new
  end

  def create
    Rails.logger.info "🔄 Create reservation"
    Rails.logger.info "📝 Params: #{params.inspect}"
    
    begin
      # パラメータの処理（時間をJST として適切に処理）
      processed_params = reservation_params.dup
      
      # start_time, end_time が含まれている場合、JST として処理
      if processed_params[:start_time].present?
        # ISO8601形式の文字列をJST時間としてパース
        processed_params[:start_time] = Time.zone.parse(processed_params[:start_time])
        Rails.logger.info "🕐 Parsed start_time: #{processed_params[:start_time]} (JST)"
      end
      
      if processed_params[:end_time].present?
        processed_params[:end_time] = Time.zone.parse(processed_params[:end_time])  
        Rails.logger.info "🕐 Parsed end_time: #{processed_params[:end_time]} (JST)"
      end
      
      # date と time パラメータがある場合は統合処理
      if processed_params[:date].present? && processed_params[:time].present?
        start_datetime = Time.zone.parse("#{processed_params[:date]} #{processed_params[:time]}")
        processed_params[:start_time] = start_datetime
        
        # コースから終了時間を計算
        if processed_params[:course].present?
          duration = case processed_params[:course]
                    when '40分' then 40.minutes
                    when '60分' then 60.minutes
                    when '80分' then 80.minutes
                    else 60.minutes
                    end
          processed_params[:end_time] = start_datetime + duration
        end
        
        # date, time パラメータは削除
        processed_params.delete(:date)
        processed_params.delete(:time)
      end
      
      # individual_interval_minutesの処理（空文字列をnullに変換）
      if processed_params[:individual_interval_minutes].present?
        if processed_params[:individual_interval_minutes].to_s.strip == ''
          processed_params[:individual_interval_minutes] = nil
        else
          processed_params[:individual_interval_minutes] = processed_params[:individual_interval_minutes].to_i
        end
      end
      
      # 予約オブジェクトを作成
      @reservation = Reservation.new(processed_params)
      
      # 管理者用のバリデーションスキップ設定（営業時間はチェックする）
      @reservation.skip_advance_booking_validation = true
      @reservation.skip_advance_notice_validation = true
      
      # インターバル設定がある場合は時間バリデーションをスキップ
      effective_interval = @reservation.effective_interval_minutes
      if effective_interval && effective_interval > 0
        @reservation.skip_time_validation = true
      end
      
      # キャンセルステータスで作成する場合はcancel!メソッドを使用
      if processed_params[:status] == 'cancelled'
        Rails.logger.info "🔄 Creating cancelled reservation"
        if @reservation.save
          @reservation.cancel!(processed_params[:cancellation_reason])
          success = true
        else
          success = false
        end
      else
        success = @reservation.save
      end
      
      if success
        Rails.logger.info "✅ Reservation created successfully"
        respond_to do |format|
          format.html { redirect_to calendar_admin_reservations_path, notice: '予約を作成しました' }
          format.json { render json: { success: true, id: @reservation.id } }
        end
      else
        Rails.logger.error "❌ Reservation creation failed: #{@reservation.errors.full_messages}"
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: { success: false, error: @reservation.errors.full_messages.join(', ') } }
        end
      end
    rescue => e
      Rails.logger.error "❌ Create error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { success: false, error: e.message } }
      end
    end
  end

  def edit
  end

  def update
    Rails.logger.info "🔄 Update reservation #{@reservation.id}"
    Rails.logger.info "📝 Params: #{params.inspect}"
    
    begin
      # パラメータの処理（時間をJST として適切に処理）
      processed_params = reservation_params.dup
      
      # start_time, end_time が含まれている場合、JST として処理
      if processed_params[:start_time].present?
        # ISO8601形式の文字列をJST時間としてパース
        processed_params[:start_time] = Time.zone.parse(processed_params[:start_time])
        Rails.logger.info "🕐 Parsed start_time: #{processed_params[:start_time]} (JST)"
      end
      
      if processed_params[:end_time].present?
        processed_params[:end_time] = Time.zone.parse(processed_params[:end_time])  
        Rails.logger.info "🕐 Parsed end_time: #{processed_params[:end_time]} (JST)"
      end
      
      # date と time パラメータがある場合は統合処理
      if processed_params[:date].present? && processed_params[:time].present?
        start_datetime = Time.zone.parse("#{processed_params[:date]} #{processed_params[:time]}")
        processed_params[:start_time] = start_datetime
        
        # コースから終了時間を計算
        if processed_params[:course].present?
          duration = case processed_params[:course]
                    when '40分' then 40.minutes
                    when '60分' then 60.minutes
                    when '80分' then 80.minutes
                    else 60.minutes
                    end
          processed_params[:end_time] = start_datetime + duration
        end
        
        # date, time パラメータは削除
        processed_params.delete(:date)
        processed_params.delete(:time)
      end
      
      # individual_interval_minutesの処理（空文字列をnullに変換）
      if processed_params[:individual_interval_minutes].present?
        if processed_params[:individual_interval_minutes].to_s.strip == ''
          processed_params[:individual_interval_minutes] = nil
        else
          processed_params[:individual_interval_minutes] = processed_params[:individual_interval_minutes].to_i
    end
  end

      # ドラッグ更新の場合はインターバル時間を追加しない
      is_drag_update = params[:is_drag_update] == true
      effective_interval = nil
      
      if !is_drag_update
        # インターバル設定を反映して予約の終了時間を調整
        
        if processed_params[:individual_interval_minutes].present? && processed_params[:individual_interval_minutes] > 0
          # 個別インターバル設定がある場合
          effective_interval = processed_params[:individual_interval_minutes]
        elsif processed_params[:individual_interval_minutes].nil?
          # システム設定を使用する場合
          effective_interval = ApplicationSetting.current.reservation_interval_minutes
        end
        
        if effective_interval && effective_interval > 0 && processed_params[:end_time].present?
          # インターバル時間をそのまま追加（丸め処理なし）
          processed_params[:end_time] = processed_params[:end_time] + effective_interval.minutes
          Rails.logger.info "🕐 Adjusted end_time with interval: #{processed_params[:end_time]} (+#{effective_interval}分)"
        end
      else
        Rails.logger.info "🔄 Drag update detected, skipping interval adjustment"
      end
      
      Rails.logger.info "🔄 Processed params: #{processed_params.inspect}"
      Rails.logger.info "🔄 Individual interval minutes: #{processed_params[:individual_interval_minutes]}"
      
      # 管理者用のバリデーションスキップ設定（営業時間はチェックする）
      @reservation.skip_advance_booking_validation = true
      @reservation.skip_advance_notice_validation = true
      
      # インターバル設定がある場合、またはドラッグ更新の場合は時間バリデーションをスキップ
      if (effective_interval && effective_interval > 0) || is_drag_update
        @reservation.skip_time_validation = true
        Rails.logger.info "🔄 Skipping time validation for #{is_drag_update ? 'drag update' : 'interval adjustment'}"
      end
      
      # ドラッグ更新時は、送信された時間をそのまま使用（インターバル時間は既に含まれている）
      if is_drag_update
        Rails.logger.info "🔄 Drag update detected, using time as-is for overlap validation"
      end
      
      # キャンセルステータスに変更する場合はcancel!メソッドを使用
      if processed_params[:status] == 'cancelled' && @reservation.status != 'cancelled'
        Rails.logger.info "🔄 Cancelling reservation #{@reservation.id}"
        @reservation.cancel!(processed_params[:cancellation_reason])
        success = true
      else
        success = @reservation.update(processed_params)
      end
      
      if success
        Rails.logger.info "✅ Reservation updated successfully"
        
        respond_to do |format|
          format.html { redirect_to calendar_admin_reservations_path, notice: '予約を更新しました' }
          format.json { 
            render json: { 
              success: true, 
              id: @reservation.id,
              start_time: @reservation.start_time.in_time_zone('Asia/Tokyo').iso8601,
              end_time: @reservation.end_time.in_time_zone('Asia/Tokyo').iso8601
            } 
          }
        end
      else
        Rails.logger.error "❌ Reservation update failed: #{@reservation.errors.full_messages}"
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: { success: false, error: @reservation.errors.full_messages.join(', ') } }
        end
      end
    rescue => e
      Rails.logger.error "❌ Update error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { success: false, error: e.message } }
      end
    end
  end

  def destroy
    @reservation.destroy
      
      respond_to do |format|
      format.html { redirect_to calendar_admin_reservations_path, notice: '予約を削除しました' }
      format.json { render json: { success: true } }
    end
  end

  # キャンセル統計と履歴を取得
  def cancellation_stats
    Rails.logger.info "📊 Fetching cancellation stats"
    
    # 今月の統計
    current_month = Time.current.beginning_of_month
    this_month_reservations = Reservation.where(created_at: current_month..current_month.end_of_month)
    this_month_cancelled = this_month_reservations.where(status: :cancelled).count
    this_month_total = this_month_reservations.count
    cancelled_rate = this_month_total > 0 ? (this_month_cancelled.to_f / this_month_total * 100).round(1) : 0

    Rails.logger.info "📊 This month stats: total=#{this_month_total}, cancelled=#{this_month_cancelled}, rate=#{cancelled_rate}%"

    # 最近のキャンセル履歴（過去30日、最新5件）
    recent_cancelled = Reservation.includes(:user)
      .where(status: :cancelled)
      .where('updated_at >= ?', 30.days.ago)  # cancelled_atの代わりにupdated_atを使用
      .order(updated_at: :desc)
      .limit(5)

    Rails.logger.info "📊 Found #{recent_cancelled.count} recent cancelled reservations"

    cancelled_history = recent_cancelled.map do |reservation|
      {
        id: reservation.id,
        customer_name: reservation.name || reservation.user&.name || '未設定',
        cancelled_at: reservation.updated_at.strftime('%m/%d %H:%M'),  # updated_atを使用
        reason: reservation.cancellation_reason,
        course: reservation.course
      }
    end

    Rails.logger.info "📊 Cancellation history: #{cancelled_history.inspect}"

    render json: {
      cancelled_count: this_month_cancelled,
      cancelled_rate: cancelled_rate,
      total_reservations: this_month_total,
      cancelled_history: cancelled_history
    }
  end

  private

  def set_reservation
    @reservation = Reservation.find(params[:id])
  end

  def reservation_params
    params.require(:reservation).permit(
      :start_time, :end_time, :course, :status, :cancellation_reason, :note, :user_id,
      :name, :date, :time, :ticket_id, :individual_interval_minutes
    )
  end

  def get_status_colors(status)
    case status.to_s
    when 'confirmed'
      { bg: '#28a745', border: '#1e7e34', text: 'white' }
    when 'tentative'
      { bg: '#ffc107', border: '#e0a800', text: '#212529' }
    when 'cancelled'
      { bg: '#dc3545', border: '#bd2130', text: 'white' }
    when 'completed'
      { bg: '#6f42c1', border: '#59359a', text: 'white' }
    when 'no_show'
      { bg: '#6c757d', border: '#545b62', text: 'white' }
    else
      { bg: '#17a2b8', border: '#138496', text: 'white' }
    end
  end

  def get_shift_colors(shift_type)
    case shift_type.to_s
    when 'normal'
      { bg: '#17a2b8', border: '#138496', text: 'white' }
    when 'extended'
      { bg: '#fd7e14', border: '#e8690b', text: 'white' }
    when 'shortened'
      { bg: '#6f42c1', border: '#5a32a3', text: 'white' }
    when 'closed'
      { bg: '#6c757d', border: '#545b62', text: 'white' }
    when 'custom'
      { bg: '#20c997', border: '#1ea085', text: 'white' }
    else
      { bg: '#6c757d', border: '#545b62', text: 'white' }
    end
  end

  def process_reservation_params(params)
    processed_params = params.permit(
      :name, :course, :status, :note, :user_id, :ticket_id,
      :start_time, :end_time, :date, :time, :individual_interval_minutes
    ).to_h.with_indifferent_access
  
    Rails.logger.info "🔍 Raw params: #{params.inspect}"
    Rails.logger.info "🔍 Processed params before: #{processed_params.inspect}"
    
    # date + time から start_time を作成
    if processed_params[:date].present? && processed_params[:time].present?
      begin
        date = Date.parse(processed_params[:date])
        time_parts = processed_params[:time].split(':').map(&:to_i)
        start_datetime = Time.zone.local(date.year, date.month, date.day, time_parts[0], time_parts[1])
        processed_params[:start_time] = start_datetime
        
        # end_timeの計算（コース時間のみ、インターバルは含めない）
        if processed_params[:course].present?
          duration = case processed_params[:course]
                    when '40分' then 40.minutes
                    when '60分' then 60.minutes  
                    when '80分' then 80.minutes
                    else 60.minutes
                    end
          # 重要: end_timeはコース時間のみ。インターバルは含めない
          processed_params[:end_time] = start_datetime + duration
          
          Rails.logger.info "🕐 Set end_time to course duration only: #{processed_params[:end_time]} (course: #{duration/60}分)"
        end
        
        # date, time パラメータは削除
        processed_params.delete(:date)
        processed_params.delete(:time)
      rescue => e
        Rails.logger.error "日時変換エラー: #{e.message}"
      end
    end
    
    # individual_interval_minutesの処理（空文字列をnullに変換）
    if processed_params[:individual_interval_minutes].present?
      if processed_params[:individual_interval_minutes].to_s.strip == ''
        processed_params[:individual_interval_minutes] = nil
      else
        processed_params[:individual_interval_minutes] = processed_params[:individual_interval_minutes].to_i
      end
    end
  
    Rails.logger.info "🔄 Final processed params: #{processed_params.inspect}"
    
    processed_params
  end

  def extract_course_duration(course_string)
    return 60 unless course_string.present? # デフォルト
    
    case course_string.to_s.strip
    when /40分/, '40分コース'
      40
    when /60分/, '60分コース'
      60
    when /80分/, '80分コース'
      80
    when /(\d+)分/ # 数字+分の形式
      $1.to_i
    else
      Rails.logger.warn "⚠️ Unknown course format: '#{course_string}', defaulting to 60 minutes"
      60
    end
  end

  def build_event_classes(reservation, has_interval)
    classes = ['fc-timegrid-event', reservation.status]
    classes << 'has-interval' if has_interval
    classes << 'individual-interval' if reservation.individual_interval_minutes.present?
    classes
  end

end
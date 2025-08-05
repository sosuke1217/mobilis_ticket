# app/controllers/admin/reservations_controller.rb

class Admin::ReservationsController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :set_reservation, only: [:show, :edit, :update, :destroy]

  def index
    respond_to do |format|
      format.html { redirect_to calendar_admin_reservations_path }
      format.json do
        if request.format.json?
          Rails.logger.info "🔍 JSON request received"
          
          begin
            # システム設定を取得
            @settings = ApplicationSetting.current
            Rails.logger.info "✅ ApplicationSetting loaded"
            
            # 予約を取得（キャンセル済みは除外）
            reservations = Reservation.includes(:user)
              .where(start_time: params[:start]..params[:end])
              .where.not(status: :cancelled)
              .order(:start_time)
            
            Rails.logger.info "📋 Found #{reservations.count} reservations"
            
            events = []
            
            reservations.each do |reservation|
              Rails.logger.info "🔍 Processing reservation ID=#{reservation.id}"
              
              # 顧客名を取得
              customer_name = reservation.name.present? ? reservation.name : reservation.user&.name || '未設定'
              
              # 🔧 デバッグ: 時間の詳細を確認
              Rails.logger.info "🕐 Raw DB times for reservation #{reservation.id}:"
              Rails.logger.info "  start_time (raw): #{reservation.start_time}"
              Rails.logger.info "  end_time (raw): #{reservation.end_time}"
              Rails.logger.info "  start_time.class: #{reservation.start_time.class}"
              Rails.logger.info "  Time.zone: #{Time.zone}"
              Rails.logger.info "  Rails.application.config.time_zone: #{Rails.application.config.time_zone}"
              
              # JST時間として処理（複数の方法を試す）
              start_in_jst = reservation.start_time.in_time_zone('Asia/Tokyo')
              end_in_jst = reservation.end_time.in_time_zone('Asia/Tokyo')
              
              Rails.logger.info "  start_in_jst: #{start_in_jst}"
              Rails.logger.info "  end_in_jst: #{end_in_jst}"
              
              # 🔧 修正: タイムゾーン情報なしのISO8601形式で送信
              # FullCalendarがローカル時間として解釈するように
              start_iso = start_in_jst.strftime('%Y-%m-%dT%H:%M:%S')
              end_iso = end_in_jst.strftime('%Y-%m-%dT%H:%M:%S')
              
              Rails.logger.info "🕐 Sending to FullCalendar:"
              Rails.logger.info "  start_iso: #{start_iso}"
              Rails.logger.info "  end_iso: #{end_iso}"
              
              event = {
                id: reservation.id,
                title: "#{customer_name} - #{reservation.course}",
                start: start_iso,  # タイムゾーン情報なしで送信
                end: end_iso,      # タイムゾーン情報なしで送信
                backgroundColor: getEventColor(reservation.status),
                borderColor: getEventColor(reservation.status),
                textColor: 'white',
                className: reservation.status,  # ステータスに応じたCSSクラス
                extendedProps: {
                  status: reservation.status,
                  course: reservation.course,
                  staff_id: reservation.user_id,
                  memo: reservation.note,
                  customer: {
                    id: reservation.user_id,
                    name: customer_name,
                    kana: reservation.user&.respond_to?(:kana) ? reservation.user.kana : nil,
                    phone: reservation.user&.phone_number,
                    email: reservation.user&.email,
                    birth_date: reservation.user&.birth_date&.strftime('%Y-%m-%d')
                  }
                }
              }
              
              events << event
              Rails.logger.info "✅ Successfully processed reservation #{reservation.id}"
              
              # インターバルイベントも同様に修正
              if @settings.reservation_interval_minutes > 0
                interval_start_iso = end_in_jst.strftime('%Y-%m-%dT%H:%M:%S')
                interval_end_iso = (end_in_jst + @settings.reservation_interval_minutes.minutes).strftime('%Y-%m-%dT%H:%M:%S')
                
                interval_event = {
                  id: "interval-after-#{reservation.id}",
                  title: "整理時間 (#{@settings.reservation_interval_minutes}分)",
                  start: interval_start_iso,
                  end: interval_end_iso,
                  backgroundColor: '#17a2b8',
                  borderColor: '#17a2b8',
                  textColor: 'white',
                  className: 'break',  # 休憩時間のCSSクラス
                  extendedProps: {
                    status: 'break',
                    type: 'interval',
                    reservation_id: reservation.id
                  }
                }
                
                events << interval_event
                Rails.logger.info "✅ Added interval event for reservation #{reservation.id}"
              end
            end
            
            Rails.logger.info "✅ Successfully processed #{events.length} events"
            Rails.logger.info "📤 Sample event data: #{events.first&.slice(:id, :title, :start, :end)}"
            
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
      
      Rails.logger.info "🔄 Processed params: #{processed_params.inspect}"
      Rails.logger.info "🔄 Individual interval minutes: #{processed_params[:individual_interval_minutes]}"
      
      @reservation = Reservation.new(processed_params)
      
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
      
      Rails.logger.info "🔄 Processed params: #{processed_params.inspect}"
      Rails.logger.info "🔄 Individual interval minutes: #{processed_params[:individual_interval_minutes]}"
      
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

  def getEventColor(status)
    case status
    when 'confirmed'
      '#28a745'  # 緑 - 確定予約
    when 'tentative'
      '#ffc107'  # 黄 - 仮予約
    when 'cancelled'
      '#dc3545'  # 赤 - キャンセル
    when 'completed'
      '#6c757d'  # グレー - 完了
    when 'no_show'
      '#fd7e14'  # オレンジ - 無断キャンセル
    when 'break'
      '#17a2b8'  # 青 - 休憩
    else
      '#007bff'  # デフォルト - 青
    end
  end
end
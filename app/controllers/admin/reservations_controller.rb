# app/controllers/admin/reservations_controller.rb
# この内容で既存のファイルを更新してください

class Admin::ReservationsController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :set_reservation, only: [:show, :edit, :update, :destroy]

  def index
    respond_to do |format|
      format.html { redirect_to calendar_admin_reservations_path }
      format.json do
        # JSONリクエストのみを処理
        if request.format.json?
          Rails.logger.info "🔍 JSON request received"
          Rails.logger.info "📋 Params: #{params.inspect}"
          Rails.logger.info "📋 Request format: #{request.format}"
          Rails.logger.info "📋 Accept header: #{request.headers['Accept']}"
          
          begin
            Rails.logger.info "🔍 Starting calendar data fetch"
            
            # システム設定を取得
            @settings = ApplicationSetting.current
            Rails.logger.info "✅ ApplicationSetting loaded: interval=#{@settings.reservation_interval_minutes}min"
            
            # 予約を取得
            reservations = Reservation.includes(:user)
              .where(start_time: params[:start]..params[:end])
              .order(:start_time)
            
            Rails.logger.info "📋 Found #{reservations.count} reservations in date range"
            
            events = []
            
            reservations.each_with_index do |reservation, index|
              Rails.logger.info "🔍 Processing reservation #{index + 1}/#{reservations.count}: ID=#{reservation.id}"
              Rails.logger.info "👤 User info: #{reservation.user&.attributes&.slice('id', 'name', 'phone_number', 'email', 'birth_date')}"
              
              # メイン予約イベント
              # 顧客名を取得（nameフィールドまたはuser.name）
              customer_name = reservation.name.present? ? reservation.name : reservation.user&.name || '未設定'
              
              event = {
                id: reservation.id,
                title: "#{customer_name} - #{reservation.course}",
                start: reservation.start_time.iso8601,
                end: reservation.end_time.iso8601,
                backgroundColor: getEventColor(reservation.status),
                borderColor: getEventColor(reservation.status),
                textColor: 'white',
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
              
              # インターバルイベントを追加
              if @settings.reservation_interval_minutes > 0
                interval_event = {
                  id: "interval-after-#{reservation.id}",
                  title: "整理時間 (#{@settings.reservation_interval_minutes}分)",
                  start: reservation.end_time.iso8601,
                  end: (reservation.end_time + @settings.reservation_interval_minutes.minutes).iso8601,
                  backgroundColor: '#17a2b8',
                  borderColor: '#17a2b8',
                  textColor: 'white',
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
            Rails.logger.info "📤 Sending events: #{events.map { |e| e[:id] }.join(', ')}"
            
            Rails.logger.info "📤 Rendering JSON response"
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
          start_time: @reservation.start_time.iso8601,
          end_time: @reservation.end_time.iso8601,
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
    Rails.logger.info "🆕 Create new reservation"
    Rails.logger.info "📋 Params: #{params.inspect}"
    
    # 日時を組み合わせてstart_timeとend_timeを設定
    if params[:reservation][:date].present? && params[:reservation][:time].present?
      begin
        date = Date.parse(params[:reservation][:date])
        time = Time.parse(params[:reservation][:time])
        
        # 日本のタイムゾーンでDateTimeを作成
        start_time = Time.zone.local(date.year, date.month, date.day, time.hour, time.min)
        
        # コースの長さを取得してend_timeを計算
        duration_minutes = case params[:reservation][:course]
                          when '60分' then 60
                          when '80分' then 80
                          when '90分' then 90
                          when '120分' then 120
                          else 60
                          end
        
        end_time = start_time + duration_minutes.minutes
        
        Rails.logger.info "🕐 Parsed times - Date: #{date}, Time: #{time}, Start: #{start_time}, End: #{end_time}"
        
        # パラメータに日時を追加
        params[:reservation][:start_time] = start_time
        params[:reservation][:end_time] = end_time
      rescue => e
        Rails.logger.error "❌ Date/time parsing error: #{e.message}"
        respond_to do |format|
          format.json { render json: { success: false, error: '日時の形式が正しくありません' } }
        end
        return
      end
    end
    
    @reservation = Reservation.create_as_admin!(reservation_params)
    
    respond_to do |format|
      Rails.logger.info "✅ Reservation created successfully"
      format.html { redirect_to calendar_admin_reservations_path, notice: '予約を作成しました' }
      format.json { render json: { success: true, id: @reservation.id } }
    end
  rescue => e
    Rails.logger.error "❌ Create error: #{e.message}"
    respond_to do |format|
      format.html { render :new, status: :unprocessable_entity }
      format.json { render json: { success: false, error: e.message } }
    end
  end

  def edit
  end

  def update
    Rails.logger.info "🔄 Update reservation #{@reservation.id}"
    Rails.logger.info "📋 Params: #{params.inspect}"
    
    # ドラッグ＆ドロップによる時間更新の場合
    if params[:reservation][:start_time].present? && params[:reservation][:end_time].present?
      begin
        # ISO文字列をパースしてタイムゾーンを正しく処理
        start_time = Time.zone.parse(params[:reservation][:start_time])
        end_time = Time.zone.parse(params[:reservation][:end_time])
        
        Rails.logger.info "🕐 Drag & Drop times - Raw: #{params[:reservation][:start_time]} -> #{start_time}"
        Rails.logger.info "🕐 Drag & Drop times - Raw: #{params[:reservation][:end_time]} -> #{end_time}"
        
        # 時間のみを更新（nameフィールドも保持）
        @reservation.update_as_admin!(
          start_time: start_time,
          end_time: end_time,
          name: @reservation.name # 既存の名前を保持
        )
        
        Rails.logger.info "✅ Reservation time updated successfully"
        
        respond_to do |format|
          format.json { render json: { success: true, id: @reservation.id } }
        end
        return
      rescue => e
        Rails.logger.error "❌ Time update error: #{e.message}"
        respond_to do |format|
          format.json { render json: { success: false, error: e.message } }
        end
        return
      end
    end
    
    # 通常の更新処理
    if params[:reservation][:date].present? && params[:reservation][:time].present?
      begin
        date = Date.parse(params[:reservation][:date])
        time = Time.parse(params[:reservation][:time])
        
        # 日本のタイムゾーンでDateTimeを作成
        start_time = Time.zone.local(date.year, date.month, date.day, time.hour, time.min)
        
        # コースの長さを取得してend_timeを計算
        duration_minutes = case params[:reservation][:course]
                          when '60分' then 60
                          when '80分' then 80
                          when '90分' then 90
                          when '120分' then 120
                          else 60
                          end
        
        end_time = start_time + duration_minutes.minutes
        
        Rails.logger.info "🕐 Parsed times - Date: #{date}, Time: #{time}, Start: #{start_time}, End: #{end_time}"
        
        # パラメータに日時を追加
        params[:reservation][:start_time] = start_time
        params[:reservation][:end_time] = end_time
      rescue => e
        Rails.logger.error "❌ Date/time parsing error: #{e.message}"
        respond_to do |format|
          format.json { render json: { success: false, error: '日時の形式が正しくありません' } }
        end
        return
      end
    end
    
    begin
      @reservation.update_as_admin!(reservation_params)
      Rails.logger.info "✅ Reservation updated successfully"
      
      respond_to do |format|
        format.html { redirect_to calendar_admin_reservations_path, notice: '予約を更新しました' }
        format.json { render json: { success: true, id: @reservation.id } }
      end
    rescue => e
      Rails.logger.error "❌ Update error: #{e.message}"
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

  private

  def set_reservation
    @reservation = Reservation.find(params[:id])
  end

  def reservation_params
    params.require(:reservation).permit(
      :start_time, :end_time, :course, :status, :note, :user_id,
      :name, :date, :time, :ticket_id
    )
  end

  def getEventColor(status)
    case status
    when 'confirmed'
      '#28a745'  # 緑 - 確定予約
    when 'pending'
      '#ffc107'  # 黄 - 保留中
    when 'cancelled'
      '#dc3545'  # 赤 - キャンセル
    when 'no_show'
      '#6c757d'  # グレー - 無断キャンセル
    when 'break'
      '#17a2b8'  # 青 - 休憩
    else
      '#007bff'  # デフォルト - 青
    end
  end
end
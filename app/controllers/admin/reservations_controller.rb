# app/controllers/admin/reservations_controller.rb の修正版（主要メソッドのみ）

class Admin::ReservationsController < ApplicationController
  include ErrorHandling
  before_action :authenticate_admin_user!

  def calendar
  end
  
  def index
    respond_to do |format|
      format.html { redirect_to admin_reservations_calendar_path }
      format.json do
        # システム設定を取得
        @settings = ApplicationSetting.current
        
        reservations = Reservation.includes(:user)
          .where(start_time: params[:start]..params[:end])
          .order(:start_time)

        # カレンダー用データに設定情報を追加
        render json: reservations.map { |reservation|
          {
            id: reservation.id,
            title: "#{reservation.name} - #{reservation.course}",
            start: reservation.start_time.iso8601,
            end: reservation.end_time.iso8601,
            backgroundColor: color_for_status(reservation.status),
            borderColor: color_for_status(reservation.status),
            textColor: '#fff',
            extendedProps: {
              name: reservation.name,
              course: reservation.course,
              status: reservation.status,
              user_id: reservation.user_id,
              note: reservation.note,
              # システム設定情報をJavaScriptに渡す
              buffer_minutes: @settings.reservation_interval_minutes,
              business_hours_start: @settings.business_hours_start,
              business_hours_end: @settings.business_hours_end,
              slot_interval: @settings.slot_interval_minutes
            }
          }
        }
      end
    end
  end

  def new
    @reservation = Reservation.new
  
    # URLクエリ（?start_time=...）から hidden_field に値を渡す
    if params[:start_time].present?
      begin
        @reservation.start_time = Time.zone.parse(params[:start_time])
      rescue ArgumentError
        # パースできない場合の保険
        flash.now[:alert] = "開始時間が不正です"
      end
    end
  end

  def create
    Rails.logger.info "🆕 Creating reservation with params: #{params.inspect}"
    
    # 新規ユーザー作成が必要かチェック
    if params[:new_user].present?
      Rails.logger.info "👤 Creating with new user"
      create_reservation_with_new_user
    else
      Rails.logger.info "👤 Creating with existing user"
      create_reservation_with_existing_user
    end
  rescue => e
    Rails.logger.error "❌ Create action failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    respond_to do |format|
      format.json { render json: { success: false, error: "予約作成中にエラーが発生しました: #{e.message}" }, status: :internal_server_error }
      format.html { redirect_to admin_reservations_calendar_path, alert: "予約作成中にエラーが発生しました" }
    end
  end
  
  def update
    unless params[:id].to_s.match?(/^\d+$/)
      logger.warn "⚠️ 不正なIDによるPATCHリクエスト: #{params[:id]}"
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "不正なIDです。" }
        format.json { render json: { success: false, error: "不正なID" }, status: :not_found }
      end
      return
    end
  
    begin
      @reservation = Reservation.find(params[:id])
      
      # 管理者による更新の場合、制限を解除
      update_params = reservation_params
      
      # 管理者用の制限なし更新を使用
      if @reservation.update_as_admin!(update_params)
        Rails.logger.info "✅ Reservation updated successfully by admin"
        respond_to do |format|
          format.json { 
            render json: { 
              success: true, 
              message: "予約を更新しました",
              reservation: {
                id: @reservation.id,
                start_time: @reservation.start_time,
                end_time: @reservation.end_time,
                status: @reservation.status
              }
            }
          }
          format.html { 
            redirect_to admin_reservations_calendar_path, 
            notice: "予約を更新しました" 
          }
        end
      else
        Rails.logger.error "❌ Reservation update failed: #{@reservation.errors.full_messages}"
        respond_to do |format|
          format.json { 
            render json: { 
              success: false, 
              error: @reservation.errors.full_messages.join(', ') 
            }, status: :unprocessable_entity 
          }
          format.html { 
            redirect_to admin_reservations_calendar_path, 
            alert: "予約の更新に失敗しました: #{@reservation.errors.full_messages.join(', ')}" 
          }
        end
      end

    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "❌ Reservation not found: ID #{params[:id]}"
      respond_to do |format|
        format.json { 
          render json: { success: false, error: "予約が見つかりません" }, 
          status: :not_found 
        }
        format.html { 
          redirect_to admin_reservations_calendar_path, 
          alert: "予約が見つかりません" 
        }
      end
    end
  end

  def destroy
    Rails.logger.info "🗑️ DELETE request for reservation ID: #{params[:id]}"
    
    begin
      @reservation = Reservation.find(params[:id])
      Rails.logger.info "✅ Found reservation: #{@reservation.name}"
      
      @reservation.destroy!
      Rails.logger.info "✅ Reservation destroyed successfully"
  
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, notice: "予約を削除しました。" }
        format.json { 
          render json: { 
            success: true, 
            message: "予約を削除しました" 
          }, status: :ok
        }
      end
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "❌ Reservation not found: #{params[:id]}"
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "予約が見つかりません。" }
        format.json { render json: { success: false, error: "予約が見つかりません" }, status: :not_found }
      end
    rescue => e
      Rails.logger.error "❌ 予約削除エラー: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "削除中にエラーが発生しました。" }
        format.json { render json: { success: false, error: "削除中にエラーが発生しました: #{e.message}" }, status: :internal_server_error }
      end
    end
  end

  def cancel
    Rails.logger.info "❌ CANCEL request for reservation ID: #{params[:id]}"
    
    begin
      @reservation = Reservation.find(params[:id])
      Rails.logger.info "✅ Found reservation for cancel: #{@reservation.name}"
      
      if @reservation.cancellable?
        cancellation_reason = params[:cancellation_reason] || "管理者によるキャンセル"
        @reservation.cancel!(cancellation_reason)
        Rails.logger.info "✅ Reservation cancelled successfully"
        
        respond_to do |format|
          format.html { redirect_to admin_reservations_calendar_path, notice: "予約をキャンセルしました。" }
          format.json { 
            render json: { 
              success: true, 
              message: "予約をキャンセルしました",
              reservation_id: @reservation.id
            }, status: :ok
          }
        end
      else
        Rails.logger.warn "⚠️ Reservation not cancellable: #{@reservation.status}"
        respond_to do |format|
          format.html { redirect_to admin_reservations_calendar_path, alert: "この予約はキャンセルできません。" }
          format.json { 
            render json: { 
              success: false, 
              error: "この予約はキャンセルできません" 
            }, status: :unprocessable_entity 
          }
        end
      end
      
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error "❌ Reservation not found for cancel: #{params[:id]}"
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "予約が見つかりません。" }
        format.json { render json: { success: false, error: "予約が見つかりません" }, status: :not_found }
      end
    rescue => e
      Rails.logger.error "❌ 予約キャンセルエラー: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "キャンセル中にエラーが発生しました。" }
        format.json { render json: { success: false, error: "キャンセル中にエラーが発生しました: #{e.message}" }, status: :internal_server_error }
      end
    end
  end

  def bulk_create
    Rails.logger.info "🔄 Bulk reservation creation started"
    
    begin
      ActiveRecord::Base.transaction do
        # パラメータの取得
        bulk_params = params.require(:bulk_reservation)
        base_reservation_params = bulk_params.require(:base_reservation)
        schedule_params = bulk_params.require(:schedule)
        
        Rails.logger.info "📝 Bulk params: #{bulk_params.inspect}"
        
        # 基本予約情報
        user_id = base_reservation_params[:user_id]
        course = base_reservation_params[:course]
        note = base_reservation_params[:note]
        status = base_reservation_params[:status] || 'confirmed'
        
        # スケジュール情報
        pattern = schedule_params[:pattern] # 'weekly' or 'monthly'
        start_date = Date.parse(schedule_params[:start_date])
        end_date = Date.parse(schedule_params[:end_date])
        start_time = schedule_params[:start_time] # "14:00"
        weekdays = schedule_params[:weekdays]&.map(&:to_i) || [] # [1, 3, 5] (月水金)
        monthly_day = schedule_params[:monthly_day]&.to_i # 毎月15日など
        
        user = User.find(user_id)
        created_reservations = []
        
        case pattern
        when 'weekly'
          created_reservations = create_weekly_reservations(
            user: user,
            course: course,
            note: note,
            status: status,
            start_date: start_date,
            end_date: end_date,
            start_time: start_time,
            weekdays: weekdays
          )
          
        when 'monthly'
          created_reservations = create_monthly_reservations(
            user: user,
            course: course,
            note: note,
            status: status,
            start_date: start_date,
            end_date: end_date,
            start_time: start_time,
            monthly_day: monthly_day
          )
          
        when 'custom'
          # カスタム日付リスト
          custom_dates = schedule_params[:custom_dates] || []
          created_reservations = create_custom_reservations(
            user: user,
            course: course,
            note: note,
            status: status,
            start_time: start_time,
            custom_dates: custom_dates
          )
        end
        
        Rails.logger.info "✅ Created #{created_reservations.length} reservations"
        
        respond_to do |format|
          format.json { 
            render json: { 
              success: true, 
              message: "#{created_reservations.length}件の予約を作成しました",
              reservations: created_reservations.map { |r| {
                id: r.id,
                start_time: r.start_time,
                end_time: r.end_time,
                status: r.status
              }}
            }, status: :created 
          }
          format.html { 
            redirect_to admin_reservations_calendar_path, 
            notice: "#{created_reservations.length}件の予約を作成しました" 
          }
        end
      end
      
    rescue => e
      Rails.logger.error "❌ Bulk creation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: false, 
            error: "一括作成中にエラーが発生しました: #{e.message}" 
          }, status: :unprocessable_entity 
        }
        format.html { 
          redirect_to admin_reservations_calendar_path, 
          alert: "一括作成中にエラーが発生しました: #{e.message}" 
        }
      end
    end
  end

  def bulk_new
    # 一括作成フォーム表示用
    Rails.logger.info "📝 Displaying bulk reservation form"
  end

  private

  def reservation_params
    params.require(:reservation).permit(
      :name, :start_time, :end_time, :course, :note, :user_id, :status, :ticket_id,
      :recurring, :recurring_type, :recurring_until, :cancellation_reason
    )
  end
  
  # ドラッグ&ドロップリクエストかどうかを判定
  def drag_drop_request?
    # JSONリクエストで、start_timeまたはend_timeのみが送信されている場合
    request.format.json? && 
    params[:reservation] && 
    (params[:reservation].keys & ['start_time', 'end_time']).any? &&
    (params[:reservation].keys & ['name', 'course', 'note']).empty?
  end
  
  # ドラッグ&ドロップ用のパラメータ
  def drag_drop_params
    params.require(:reservation).permit(:start_time, :end_time)
  end
  
  # 時間の重複チェック
  def time_conflict_exists?(update_params, current_reservation_id)
    start_time = Time.zone.parse(update_params[:start_time])
    end_time = update_params[:end_time].present? ? Time.zone.parse(update_params[:end_time]) : nil
    
    return false unless end_time
    
    interval_minutes = Reservation.interval_minutes
    
    Reservation.active
      .where.not(id: current_reservation_id)
      .where(
        '(start_time - INTERVAL ? MINUTE) < ? AND (end_time + INTERVAL ? MINUTE) > ?',
        interval_minutes, end_time, interval_minutes, start_time
      )
      .exists?
  end

  def create_reservation_with_new_user
    Rails.logger.info "📝 Creating reservation with new user"
    
    new_user_name = params[:new_user][:name]
    new_user_phone = params[:new_user][:phone_number]
    new_user_email = params[:new_user][:email]
    
    # 新規ユーザー作成
    user = User.create!(
      name: new_user_name,
      phone_number: new_user_phone,
      email: new_user_email
    )
    
    Rails.logger.info "👤 New user created: #{user.name} (ID: #{user.id})"
    
    reservation_attrs = reservation_params.merge(
      name: user.name,
      user: user
    )
    
    # 管理者用の制限なし作成を使用
    @reservation = Reservation.create_as_admin!(reservation_attrs)
    
    Rails.logger.info "✅ Reservation created successfully with new user by admin: ID=#{@reservation.id}"
    
    respond_to do |format|
      format.json { 
        render json: { 
          success: true, 
          message: "新規ユーザーと予約を作成しました",
          reservation: {
            id: @reservation.id,
            title: @reservation.name,
            start: @reservation.start_time.iso8601,
            end: @reservation.end_time.iso8601,
            description: @reservation.course,
            status: @reservation.status
          }
        }, status: :created 
      }
      format.html { 
        redirect_to admin_reservations_calendar_path, 
        notice: "新規ユーザーと予約を作成しました" 
      }
    end
    
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "❌ User or reservation creation failed: #{e.record.errors.full_messages}"
    
    respond_to do |format|
      format.json { 
        render json: { 
          success: false, 
          errors: e.record.errors.full_messages,
          error: e.record.errors.full_messages.join(', ')
        }, status: :unprocessable_entity 
      }
      format.html { 
        redirect_to admin_reservations_calendar_path, 
        alert: "ユーザー・予約作成に失敗しました: #{e.record.errors.full_messages.join(', ')}" 
      }
    end
  end
  
  def create_reservation_with_existing_user
    Rails.logger.info "📝 Creating reservation with existing user"
    
    user_id = params[:reservation][:user_id]
    user = User.find(user_id)
    Rails.logger.info "👤 User found: #{user.name} (ID: #{user.id})"
    
    reservation_attrs = reservation_params.merge(
      name: user.name,
      user: user
    )
    
    Rails.logger.info "📝 Final reservation attributes: #{reservation_attrs.inspect}"
    
    # 管理者用の制限なし作成を使用
    @reservation = Reservation.create_as_admin!(reservation_attrs)
    
    Rails.logger.info "✅ Reservation created successfully by admin: ID=#{@reservation.id}"
    
    respond_to do |format|
      format.json { 
        render json: { 
          success: true, 
          message: "予約を作成しました",
          reservation: {
            id: @reservation.id,
            title: @reservation.name,
            start: @reservation.start_time.iso8601,
            end: @reservation.end_time.iso8601,
            description: @reservation.course,
            status: @reservation.status
          }
        }, status: :created 
      }
      format.html { 
        redirect_to admin_reservations_calendar_path, 
        notice: "予約を作成しました" 
      }
    end
    
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "❌ Reservation creation failed: #{e.record.errors.full_messages}"
    
    respond_to do |format|
      format.json { 
        render json: { 
          success: false, 
          errors: e.record.errors.full_messages,
          error: e.record.errors.full_messages.join(', ')
        }, status: :unprocessable_entity 
      }
      format.html { 
        redirect_to admin_reservations_calendar_path, 
        alert: "予約作成に失敗しました: #{e.record.errors.full_messages.join(', ')}" 
      }
    end
  end
  
  def new_user_params
    params.require(:new_user).permit(:name, :phone_number, :email, :birth_date, :address, :admin_memo, :postal_code)
  end

  def text_color_for_status(status)
    case status.to_s
    when 'tentative'
      '#000000'  # 黄色背景には黒文字
    when 'cancelled'
      '#FFFFFF'  # 赤背景には白文字
    when 'confirmed'
      '#FFFFFF'  # 緑背景には白文字
    when 'completed'
      '#FFFFFF'  # グレー背景には白文字
    when 'no_show'
      '#FFFFFF'  # オレンジ背景には白文字
    else
      '#FFFFFF'  # デフォルトは白文字
    end
  end

  def handle_calendar_error(error)
    Rails.logger.error "❌ Calendar error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    respond_to do |format|
      format.json { 
        render json: { 
          success: false, 
          error: "カレンダーデータの取得に失敗しました",
          details: Rails.env.development? ? error.message : nil
        }, status: :internal_server_error 
      }
      format.html { 
        flash[:alert] = "カレンダーの読み込みに失敗しました"
        redirect_to admin_root_path 
      }
    end
  end

  def reservation_to_json(reservation)
    {
      id: reservation.id,
      title: reservation.name || "無名",
      start: reservation.start_time&.iso8601,
      end: reservation.end_time&.iso8601,
      description: reservation.course || "",
      color: reservation.status_color,
      textColor: text_color_for_status(reservation.status),
      user_id: reservation.user_id,
      status: reservation.status,
      course: reservation.course,
      note: reservation.note,
      recurring: reservation.recurring || false,
      recurring_type: reservation.recurring_type,
      recurring_until: reservation.recurring_until,
      confirmation_sent_at: reservation.confirmation_sent_at,
      reminder_sent_at: reservation.reminder_sent_at,
      cancelled_at: reservation.cancelled_at,
      cancellation_reason: reservation.cancellation_reason
    }
  end

  def create_weekly_reservations(user:, course:, note:, status:, start_date:, end_date:, start_time:, weekdays:)
    reservations = []
    current_date = start_date
    
    while current_date <= end_date
      # 指定された曜日かチェック（0=日曜日, 1=月曜日, ...）
      if weekdays.include?(current_date.wday)
        reservation_datetime = Time.zone.parse("#{current_date} #{start_time}")
        
        # 重複チェック
        unless reservation_exists?(user, reservation_datetime)
          duration = get_duration_from_course(course)
          end_datetime = reservation_datetime + duration.minutes
          
          reservation = Reservation.create!(
            user: user,
            name: user.name,
            start_time: reservation_datetime,
            end_time: end_datetime,
            course: course,
            note: note,
            status: status
          )
          
          reservations << reservation
          Rails.logger.info "📅 Created reservation: #{reservation_datetime}"
        else
          Rails.logger.warn "⚠️ Skipped duplicate: #{reservation_datetime}"
        end
      end
      
      current_date += 1.day
    end
    
    reservations
  end
  
  def create_monthly_reservations(user:, course:, note:, status:, start_date:, end_date:, start_time:, monthly_day:)
    reservations = []
    current_month = start_date.beginning_of_month
    
    while current_month <= end_date
      # その月の指定日を計算
      begin
        target_date = Date.new(current_month.year, current_month.month, monthly_day)
        
        # 日付が範囲内かチェック
        if target_date >= start_date && target_date <= end_date
          reservation_datetime = Time.zone.parse("#{target_date} #{start_time}")
          
          # 重複チェック
          unless reservation_exists?(user, reservation_datetime)
            duration = get_duration_from_course(course)
            end_datetime = reservation_datetime + duration.minutes
            
            reservation = Reservation.create!(
              user: user,
              name: user.name,
              start_time: reservation_datetime,
              end_time: end_datetime,
              course: course,
              note: note,
              status: status
            )
            
            reservations << reservation
            Rails.logger.info "📅 Created monthly reservation: #{reservation_datetime}"
          end
        end
        
      rescue ArgumentError => e
        # 存在しない日付（例：2月30日）はスキップ
        Rails.logger.warn "⚠️ Invalid date skipped: #{current_month.year}/#{current_month.month}/#{monthly_day}"
      end
      
      current_month = current_month.next_month
    end
    
    reservations
  end
  
  def create_custom_reservations(user:, course:, note:, status:, start_time:, custom_dates:)
    reservations = []
    
    custom_dates.each do |date_str|
      begin
        target_date = Date.parse(date_str)
        reservation_datetime = Time.zone.parse("#{target_date} #{start_time}")
        
        # 重複チェック
        unless reservation_exists?(user, reservation_datetime)
          duration = get_duration_from_course(course)
          end_datetime = reservation_datetime + duration.minutes
          
          reservation = Reservation.create!(
            user: user,
            name: user.name,
            start_time: reservation_datetime,
            end_time: end_datetime,
            course: course,
            note: note,
            status: status
          )
          
          reservations << reservation
          Rails.logger.info "📅 Created custom reservation: #{reservation_datetime}"
        end
        
      rescue ArgumentError => e
        Rails.logger.warn "⚠️ Invalid date format skipped: #{date_str}"
      end
    end
    
    reservations
  end
  
  def reservation_exists?(user, datetime)
    Reservation.where(
      user: user,
      start_time: datetime.beginning_of_hour..datetime.end_of_hour
    ).exists?
  end
  
  def get_duration_from_course(course)
    case course
    when "40分" then 40
    when "60分" then 60
    when "80分" then 80
    else 60
    end
  end

end
# app/controllers/admin/reservations_controller.rb の修正版（主要メソッドのみ）

class Admin::ReservationsController < ApplicationController
  before_action :authenticate_admin_user!

  def calendar
  end
  
  def index
    @reservations = Reservation.includes(:user, :ticket).order(start_time: :asc)
  
    respond_to do |format|
      format.html
      format.json do
        render json: @reservations.map { |r|
          {
            id: r.id,
            title: r.name,
            start: r.start_time,
            end: r.end_time,
            description: r.course,
            color: r.status_color,
            textColor: text_color_for_status(r.status),
            user_id: r.user_id,
            status: r.status,
            course: r.course,
            note: r.note,
            recurring: r.recurring,
            recurring_type: r.recurring_type,
            recurring_until: r.recurring_until,
            confirmation_sent_at: r.confirmation_sent_at,
            reminder_sent_at: r.reminder_sent_at,
            cancelled_at: r.cancelled_at,
            cancellation_reason: r.cancellation_reason
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
      
      # ドラッグ&ドロップからのリクエスト（時間のみ更新）の場合
      if drag_drop_request?
        # start_timeとend_timeのみを更新
        update_params = drag_drop_params
        
        # コースに基づいた終了時間の自動計算をスキップ
        # 手動でend_timeが指定されている場合はそれを使用
        if update_params[:end_time].blank? && update_params[:start_time].present?
          # end_timeが指定されていない場合は、既存のコースから計算
          start_time = Time.zone.parse(update_params[:start_time])
          duration = case @reservation.course
                     when "40分" then 40
                     when "60分" then 60
                     when "80分" then 80
                     else 60
                     end
          update_params[:end_time] = (start_time + duration.minutes).iso8601
        end
        
        # 時間の重複チェック
        if time_conflict_exists?(update_params, @reservation.id)
          respond_to do |format|
            format.json { render json: { success: false, errors: ["この時間帯には既に別の予約が入っています"] }, status: :unprocessable_entity }
          end
          return
        end
        
        Rails.logger.info "🕐 ドラッグ&ドロップによる時間更新: #{@reservation.name} -> #{update_params[:start_time]}"
        
        if @reservation.update(update_params)
          respond_to do |format|
            format.json { render json: { success: true, message: "予約時間を更新しました" } }
          end
        else
          respond_to do |format|
            format.json { render json: { success: false, errors: @reservation.errors.full_messages }, status: :unprocessable_entity }
          end
        end
      else
        # 通常のフォームからの更新
        if @reservation.update(reservation_params)
          respond_to do |format|
            format.json { render json: { success: true, message: "予約を更新しました" } }
            format.html { redirect_to admin_reservations_calendar_path, notice: "予約を更新しました" }
          end
        else
          respond_to do |format|
            format.json { render json: { success: false, errors: @reservation.errors.full_messages }, status: :unprocessable_entity }
            format.html { render :edit, status: :unprocessable_entity }
          end
        end
      end
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "予約が見つかりません。" }
        format.json { render json: { success: false, error: "予約が見つかりません" }, status: :not_found }
      end
    rescue => e
      Rails.logger.error "予約更新エラー: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "更新中にエラーが発生しました。" }
        format.json { render json: { success: false, error: "更新中にエラーが発生しました: #{e.message}" }, status: :internal_server_error }
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
    
    Reservation.where.not(id: current_reservation_id)
               .where('start_time < ? AND end_time > ?', end_time, start_time)
               .exists?
  end

  def create_reservation_with_new_user
    Rails.logger.info "🆕 Creating reservation with new user"
    
    begin
      ActiveRecord::Base.transaction do
        # 新規ユーザーを作成
        @user = User.new(new_user_params)
        
        unless @user.save
          Rails.logger.error "❌ User creation failed: #{@user.errors.full_messages}"
          respond_to do |format|
            format.json { render json: { success: false, errors: @user.errors.full_messages }, status: :unprocessable_entity }
            format.html { redirect_to admin_reservations_calendar_path, alert: "ユーザー作成に失敗しました: #{@user.errors.full_messages.join(', ')}" }
          end
          return
        end
        
        Rails.logger.info "✅ New user created: #{@user.name} (ID: #{@user.id})"
        
        # 予約を作成（ユーザーIDを設定）
        @reservation = Reservation.new(reservation_params)
        @reservation.user_id = @user.id
        @reservation.name = @user.name  # ユーザー名を予約名に設定
        
        # 明示的に終了時間が渡されていない場合のみ自動計算
        if @reservation.end_time.blank? && @reservation.start_time.present? && @reservation.course.present?
          duration = case @reservation.course
                     when "40分" then 40
                     when "60分" then 60 
                     when "80分" then 80
                     else 60
                     end
          @reservation.end_time = @reservation.start_time + duration.minutes
        elsif @reservation.start_time.present? && @reservation.end_time.present?
          # 既に終了時間が設定されている場合は、時間が正しいかチェック
          Rails.logger.info "⏰ Using provided times: start=#{@reservation.start_time}, end=#{@reservation.end_time}"
          
          # 終了時間が開始時間より前の場合は自動修正
          if @reservation.end_time <= @reservation.start_time
            Rails.logger.warn "⚠️ End time is before start time, auto-correcting..."
            duration = case @reservation.course
                       when "40分" then 40
                       when "60分" then 60 
                       when "80分" then 80
                       else 60
                       end
            @reservation.end_time = @reservation.start_time + duration.minutes
            Rails.logger.info "⏰ Corrected end_time: #{@reservation.end_time}"
          end
        end
        
        unless @reservation.save
          Rails.logger.error "❌ Reservation creation failed: #{@reservation.errors.full_messages}"
          raise ActiveRecord::Rollback
        end
        
        Rails.logger.info "✅ New reservation created: #{@reservation.name} for #{@user.name}"
        
        respond_to do |format|
          format.json { render json: { success: true, message: "新規ユーザーと予約を作成しました", user_id: @user.id, reservation_id: @reservation.id }, status: :created }
          format.html { redirect_to admin_reservations_calendar_path, notice: "新規ユーザー「#{@user.name}」と予約を作成しました" }
        end
      end
      
    rescue => e
      Rails.logger.error "❌ Transaction failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.json { render json: { success: false, errors: ["予約作成中にエラーが発生しました: #{e.message}"] }, status: :internal_server_error }
        format.html { redirect_to admin_reservations_calendar_path, alert: "予約作成中にエラーが発生しました" }
      end
    end
  end
  
  def create_reservation_with_existing_user
    Rails.logger.info "📝 Creating reservation with existing user"
    Rails.logger.info "📥 Reservation params: #{reservation_params.inspect}"
    
    @reservation = Reservation.new(reservation_params)
    
    # ユーザーIDが指定されている場合、ユーザー名を予約名に設定
    if @reservation.user_id.present?
      user = User.find_by(id: @reservation.user_id)
      @reservation.name = user&.name || "ユーザー不明"
      Rails.logger.info "👤 User found: #{user&.name} (ID: #{user&.id})"
    else
      Rails.logger.warn "⚠️ No user_id provided"
    end
    
    # 明示的に終了時間が渡されていない場合のみ自動計算
    if @reservation.end_time.blank? && @reservation.start_time.present? && @reservation.course.present?
      duration = case @reservation.course
                 when "40分" then 40
                 when "60分" then 60
                 when "80分" then 80
                 else 60
                 end
      @reservation.end_time = @reservation.start_time + duration.minutes
      Rails.logger.info "⏰ Auto-calculated end_time: #{@reservation.end_time}"
    elsif @reservation.start_time.present? && @reservation.end_time.present?
      # 既に終了時間が設定されている場合は、時間が正しいかチェック
      Rails.logger.info "⏰ Using provided times: start=#{@reservation.start_time}, end=#{@reservation.end_time}"
      Rails.logger.info "⏰ Time difference: #{(@reservation.end_time - @reservation.start_time) / 60} minutes"
      
      # 終了時間が開始時間より前の場合は自動修正
      if @reservation.end_time <= @reservation.start_time
        Rails.logger.warn "⚠️ End time is before start time, auto-correcting..."
        duration = case @reservation.course
                   when "40分" then 40
                   when "60分" then 60
                   when "80分" then 80
                   else 60
                   end
        @reservation.end_time = @reservation.start_time + duration.minutes
        Rails.logger.info "⏰ Corrected end_time: #{@reservation.end_time}"
      end
    end

    Rails.logger.info "📝 Final reservation attributes: #{@reservation.attributes.inspect}"

    if @reservation.save
      Rails.logger.info "✅ Reservation created: #{@reservation.name} (ID: #{@reservation.id})"
      
      respond_to do |format|
        format.json { render json: { success: true, message: "予約を作成しました", reservation_id: @reservation.id }, status: :created }
        format.html { redirect_to admin_reservations_calendar_path, notice: "予約が完了しました" }
      end
    else
      Rails.logger.error "❌ Reservation creation failed: #{@reservation.errors.full_messages}"
      
      respond_to do |format|
        format.json { render json: { success: false, errors: @reservation.errors.full_messages }, status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end
  
  def new_user_params
    params.require(:new_user).permit(:name, :phone_number, :email, :birth_date, :address, :admin_memo, :postal_code)
  end

  def text_color_for_status(status)
    case status
    when 'tentative'
      '#000000'  # 黄色背景には黒文字
    else
      '#FFFFFF'  # その他は白文字
    end
  end

end
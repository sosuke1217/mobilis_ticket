class Admin::ReservationsController < ApplicationController
  before_action :authenticate_admin_user! # 管理者ログイン制限（必要に応じて）

  def calendar
  end
  
  def index
    @reservations = Reservation.order(start_time: :asc)
  
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
            color: color_for_course(r.course),
            user_id: r.user_id
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
    # 新規ユーザー作成が必要かチェック
    if params[:new_user].present?
      create_reservation_with_new_user
    else
      create_reservation_with_existing_user
    end
  end
  
  def available_slots
    date = Date.parse(params[:date])
    @slots = Reservation.available_slots_for(date)
  
    render partial: "available_slots", locals: { slots: @slots }
  end

  def destroy
    begin
      @reservation = Reservation.find(params[:id])
      @reservation.destroy
  
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, notice: "予約を削除しました。" }
        format.json { 
          if @reservation.destroyed?
            render json: { success: true, message: "予約を削除しました" }, status: :ok
          else
            render json: { success: false, errors: @reservation.errors.full_messages }, status: :unprocessable_entity
          end
        }
      end
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "予約が見つかりません。" }
        format.json { render json: { success: false, error: "予約が見つかりません" }, status: :not_found }
      end
    rescue => e
      Rails.logger.error "予約削除エラー: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "削除中にエラーが発生しました。" }
        format.json { render json: { success: false, error: "削除中にエラーが発生しました: #{e.message}" }, status: :internal_server_error }
      end
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
            format.json { render json: { success: true } }
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
  
  private

  def reservation_params
    params.require(:reservation).permit(:name, :start_time, :end_time, :course, :note, :user_id)
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

  def color_for_course(course)
    case course
    when "40分" then "#5cb85c"  # 緑
    when "60分" then "#0275d8"  # 青
    when "80分" then "#d9534f"  # 赤
    else "#6c757d"              # グレー（未指定）
    end
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
    
    @reservation = Reservation.new(reservation_params)
  
    if @reservation.save
      Rails.logger.info "✅ Reservation created: #{@reservation.name}"
      
      respond_to do |format|
        format.json { render json: { success: true, message: "予約を作成しました" }, status: :created }
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

end
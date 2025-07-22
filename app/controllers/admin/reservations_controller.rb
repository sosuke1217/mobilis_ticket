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
            user_id: r.user_id  # ← これを追加
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
    @reservation = Reservation.new(reservation_params)
  
    if @reservation.save
      respond_to do |format|
        format.json { render json: { success: true }, status: :created }
        format.html { redirect_to admin_reservations_calendar_path, notice: "予約が完了しました" }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, errors: @reservation.errors.full_messages }, status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
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
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "予約が見つかりません。" }
        format.json { render json: { success: false, error: "予約が見つかりません" }, status: :not_found }
      end
    rescue => e
      Rails.logger.error "予約更新エラー: #{e.message}"
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "更新中にエラーが発生しました。" }
        format.json { render json: { success: false, error: "更新中にエラーが発生しました" }, status: :internal_server_error }
      end
    end
  end
  
  
  private

  def reservation_params
    params.require(:reservation).permit(:name, :start_time, :end_time, :course, :note, :user_id)
  end

  def color_for_course(course)
    case course
    when "40分" then "#5cb85c"  # 緑
    when "60分" then "#0275d8"  # 青
    when "80分" then "#d9534f"  # 赤
    else "#6c757d"              # グレー（未指定）
    end
  end
end
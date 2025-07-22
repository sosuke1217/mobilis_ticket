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
            color: color_for_course(r.course)
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
        format.json { render json: { errors: @reservation.errors.full_messages }, status: :unprocessable_entity }
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
        format.json { head :no_content }
      end
    rescue ActiveRecord::RecordNotFound
      respond_to do |format|
        format.html { redirect_to admin_reservations_calendar_path, alert: "すでに削除されています。" }
        format.json { head :not_found }
      end
    end
  end
  
  # Admin::ReservationsController
  def update
    unless params[:id].to_s.match?(/^\d+$/)
      logger.warn "⚠️ 不正なIDによるPATCHリクエスト: #{params[:id]}"
      head :not_found and return
    end
  
    @reservation = Reservation.find(params[:id])
  
    if @reservation.update(reservation_params)
      respond_to do |format|
        format.json { render json: { success: true } }
        format.html { redirect_to admin_reservations_calendar_path, notice: "予約を更新しました" }
      end
    else
      respond_to do |format|
        format.json { render json: { errors: @reservation.errors.full_messages }, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
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

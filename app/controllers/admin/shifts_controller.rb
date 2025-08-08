class Admin::ShiftsController < ApplicationController
  before_action :authenticate_admin_user!, except: [:for_date]
  before_action :set_shift, only: [:show, :update, :destroy]
  skip_before_action :verify_authenticity_token, only: [:for_date]

  def index
    @shifts = Shift.recent
    render json: @shifts.map(&:as_json_with_display)
  end

  def show
    render json: @shift.as_json_with_display
  end

  # 指定日のシフトを取得
  def for_date
    begin
      date = Date.parse(params[:date])
      shift = Shift.for_date(date).first
      
      Rails.logger.info "🔍 Fetching shift for date: #{date}, found: #{shift&.id}"
      
      if shift
        render json: { 
          success: true, 
          shift: shift.as_json_with_display,
          requires_time: shift.requires_time?,
          business_hours: shift.business_hours
        }
      else
        render json: { 
          success: true, 
          shift: nil,
          requires_time: false,
          business_hours: nil
        }
      end
    rescue => e
      Rails.logger.error "❌ Error in for_date: #{e.message}"
      render json: { 
        success: false, 
        error: e.message 
      }, status: :bad_request
    end
  end

  def create
    @shift = Shift.new(shift_params)
    
    if @shift.save
      render json: { success: true, shift: @shift.as_json_with_display }
    else
      render json: { success: false, errors: @shift.errors.full_messages }
    end
  end

  def update
    if @shift.update(shift_params)
      render json: { success: true, shift: @shift.as_json_with_display }
    else
      render json: { success: false, errors: @shift.errors.full_messages }
    end
  end

  def destroy
    if @shift.destroy
      render json: { success: true }
    else
      render json: { success: false, errors: @shift.errors.full_messages }
    end
  end

  private

  def set_shift
    @shift = Shift.find(params[:id])
  end

  def shift_params
    params.require(:shift).permit(:date, :shift_type, :start_time, :end_time, :notes, breaks: [])
  end
end

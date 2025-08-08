class Admin::ShiftsController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :set_shift, only: [:show, :update, :destroy]

  def index
    @shifts = Shift.recent
    render json: @shifts.map(&:as_json_with_display)
  end

  def show
    render json: @shift.as_json_with_display
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

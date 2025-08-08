class Admin::ShiftsController < ApplicationController
  before_action :authenticate_admin_user!, except: [:for_date]
  before_action :set_shift, only: [:show, :update, :destroy]
  skip_before_action :verify_authenticity_token, only: [:for_date]

  def index
    @shifts = Shift.recent
    @shift = Shift.new
    
    respond_to do |format|
      format.html
      format.json { 
        if @shifts.any?
          shifts_data = @shifts.map do |shift|
            {
              id: shift.id,
              date: shift.date.strftime('%Y-%m-%d'),
              date_display: shift.date.strftime('%m/%d'),
              weekday: shift.date.strftime('%a'),
              shift_type: shift.shift_type,
              shift_type_display: shift.shift_type_display,
              shift_type_badge_class: shift.shift_type_badge_class,
              start_time: shift.start_time&.strftime('%H:%M'),
              end_time: shift.end_time&.strftime('%H:%M'),
              business_hours: shift.business_hours,
              business_hours_duration: shift.business_hours_duration,
              breaks: shift.breaks || [],
              breaks_display: shift.breaks_display,
              notes: shift.notes,
              created_at: shift.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
              updated_at: shift.updated_at&.strftime('%Y-%m-%d %H:%M:%S')
            }
          end
          render json: shifts_data
        else
          render json: []
        end
      }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { 
        shift_data = {
          id: @shift.id,
          date: @shift.date.strftime('%Y-%m-%d'),
          date_display: @shift.date.strftime('%m/%d'),
          weekday: @shift.date.strftime('%a'),
          shift_type: @shift.shift_type,
          shift_type_display: @shift.shift_type_display,
          shift_type_badge_class: @shift.shift_type_badge_class,
          start_time: @shift.start_time&.strftime('%H:%M'),
          end_time: @shift.end_time&.strftime('%H:%M'),
          business_hours: @shift.business_hours,
          business_hours_duration: @shift.business_hours_duration,
          breaks: @shift.breaks || [],
          breaks_display: @shift.breaks_display,
          notes: @shift.notes,
          created_at: @shift.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
          updated_at: @shift.updated_at&.strftime('%Y-%m-%d %H:%M:%S')
        }
        render json: shift_data
      }
    end
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
      respond_to do |format|
        format.html { redirect_to admin_shifts_path, notice: 'シフトを作成しました' }
        format.json { 
          shift_data = {
            id: @shift.id,
            date: @shift.date.strftime('%Y-%m-%d'),
            date_display: @shift.date.strftime('%m/%d'),
            weekday: @shift.date.strftime('%a'),
            shift_type: @shift.shift_type,
            shift_type_display: @shift.shift_type_display,
            shift_type_badge_class: @shift.shift_type_badge_class,
            start_time: @shift.start_time&.strftime('%H:%M'),
            end_time: @shift.end_time&.strftime('%H:%M'),
            business_hours: @shift.business_hours,
            business_hours_duration: @shift.business_hours_duration,
            breaks: @shift.breaks || [],
            breaks_display: @shift.breaks_display,
            notes: @shift.notes,
            created_at: @shift.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
            updated_at: @shift.updated_at&.strftime('%Y-%m-%d %H:%M:%S')
          }
          render json: { success: true, shift: shift_data }
        }
      end
    else
      respond_to do |format|
        format.html { 
          @shifts = Shift.recent
          flash.now[:alert] = 'シフトの作成に失敗しました'
          render :index, status: :unprocessable_entity
        }
        format.json { render json: { success: false, errors: @shift.errors.full_messages } }
      end
    end
  end

  def update
    if @shift.update(shift_params)
      respond_to do |format|
        format.html { redirect_to admin_shifts_path, notice: 'シフトを更新しました' }
        format.json { 
          shift_data = {
            id: @shift.id,
            date: @shift.date.strftime('%Y-%m-%d'),
            date_display: @shift.date.strftime('%m/%d'),
            weekday: @shift.date.strftime('%a'),
            shift_type: @shift.shift_type,
            shift_type_display: @shift.shift_type_display,
            shift_type_badge_class: @shift.shift_type_badge_class,
            start_time: @shift.start_time&.strftime('%H:%M'),
            end_time: @shift.end_time&.strftime('%H:%M'),
            business_hours: @shift.business_hours,
            business_hours_duration: @shift.business_hours_duration,
            breaks: @shift.breaks || [],
            breaks_display: @shift.breaks_display,
            notes: @shift.notes,
            created_at: @shift.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
            updated_at: @shift.updated_at&.strftime('%Y-%m-%d %H:%M:%S')
          }
          render json: { success: true, shift: shift_data }
        }
      end
    else
      respond_to do |format|
        format.html { 
          flash.now[:alert] = 'シフトの更新に失敗しました'
          render :show, status: :unprocessable_entity
        }
        format.json { render json: { success: false, errors: @shift.errors.full_messages } }
      end
    end
  end

  def destroy
    if @shift.destroy
      respond_to do |format|
        format.html { redirect_to admin_shifts_path, notice: 'シフトを削除しました' }
        format.json { render json: { success: true, message: 'シフトを削除しました' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to admin_shifts_path, alert: 'シフトの削除に失敗しました' }
        format.json { render json: { success: false, errors: @shift.errors.full_messages } }
      end
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

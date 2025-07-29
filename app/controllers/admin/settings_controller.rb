# app/controllers/admin/settings_controller.rb

class Admin::SettingsController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :set_setting, only: [:index, :update]

  def index
    @settings = ApplicationSetting.current
  end

  def update
    @settings = ApplicationSetting.current
    
    if @settings.update(setting_params)
      redirect_to admin_settings_path, 
                  notice: '設定を更新しました。'
    else
      flash.now[:alert] = '設定の更新に失敗しました。'
      render :index, status: :unprocessable_entity
    end
  end

  private

  def set_setting
    @settings = ApplicationSetting.current
  end

  def setting_params
    params.require(:application_setting).permit(
      :reservation_interval_minutes,
      :business_hours_start,
      :business_hours_end,
      :slot_interval_minutes,
      :max_advance_booking_days,
      :min_advance_booking_hours,
      :sunday_closed
    )
  end
end
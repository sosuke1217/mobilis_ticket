# app/controllers/admin/settings_controller.rb

class Admin::SettingsController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :set_setting, only: [:index, :update, :update_business_hours, :business_status]

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

  # 営業時間のリアルタイム更新エンドポイント
  def update_business_hours
    Rails.logger.info "🕒 Business hours update request: #{params.inspect}"
    
    # バリデーション実行
    validation_errors = validate_business_hours_params
    
    if validation_errors.any?
      return render json: { 
        success: false, 
        errors: validation_errors 
      }
    end
    
    begin
      old_start = @settings.business_hours_start
      old_end = @settings.business_hours_end
      
      new_start = params[:business_hours_start].to_i
      new_end = params[:business_hours_end].to_i
      
      # トランザクション内で更新
      ApplicationSetting.transaction do
        if @settings.update!(
          business_hours_start: new_start,
          business_hours_end: new_end
        )
          
          # 成功ログ
          Rails.logger.info "✅ Business hours updated successfully: #{old_start}:00-#{old_end}:00 → #{new_start}:00-#{new_end}:00"
          
          # WebSocket通知
          broadcast_business_hours_change(old_start, old_end, new_start, new_end)
          
          # レスポンス
          render json: { 
            success: true,
            message: "営業時間を更新しました",
            data: BusinessHoursSerializer.new(@settings).as_json,
            changes: {
              old_hours: "#{old_start}:00-#{old_end}:00",
              new_hours: "#{new_start}:00-#{new_end}:00",
              extension: calculate_hour_changes(old_start, old_end, new_start, new_end)
            }
          }
        end
      end
      
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "❌ Validation failed: #{e.message}"
      render json: { 
        success: false, 
        error: "バリデーションエラー: #{e.record.errors.full_messages.join(', ')}" 
      }
      
    rescue => e
      Rails.logger.error "❌ Business hours update failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render json: { 
        success: false, 
        error: "設定の更新中にエラーが発生しました" 
      }
    end
  end
  
  # 現在の営業状態を取得
  def business_status
    current_time = Time.current
    current_hour = current_time.hour
    
    is_open = (current_hour >= @settings.business_hours_start && 
               current_hour < @settings.business_hours_end)
    
    # 営業開始/終了まであと何時間か
    if is_open
      hours_until_close = @settings.business_hours_end - current_hour
      time_until_close = hours_until_close > 0 ? "#{hours_until_close}時間後" : "まもなく"
    else
      # 次の営業開始まで
      if current_hour < @settings.business_hours_start
        hours_until_open = @settings.business_hours_start - current_hour
        time_until_open = "#{hours_until_open}時間後"
      else
        # 翌日の営業開始まで
        hours_until_open = (24 - current_hour) + @settings.business_hours_start
        time_until_open = "#{hours_until_open}時間後（翌日）"
      end
    end
    
    render json: {
      is_open: is_open,
      current_time: current_time.strftime("%H:%M"),
      business_hours: {
        start: @settings.business_hours_start,
        end: @settings.business_hours_end,
        formatted: "#{@settings.business_hours_start}:00-#{@settings.business_hours_end}:00"
      },
      status_message: is_open ? 
        "営業中（#{time_until_close}に終了）" : 
        "営業時間外（#{time_until_open}に開始）",
      time_until_change: is_open ? time_until_close : time_until_open
    }
  end

  # テスト用エンドポイント（開発環境のみ）
  def test_shift_changes
    return head :forbidden unless Rails.env.development?
    
    test_scenarios = [
      { start: 9, end: 22, description: "営業時間拡張テスト" },
      { start: 11, end: 20, description: "営業時間短縮テスト" },
      { start: 8, end: 24, description: "最大営業時間テスト" },
      { start: 10, end: 21, description: "デフォルト営業時間テスト" }
    ]
    
    render json: {
      success: true,
      test_scenarios: test_scenarios,
      current_hours: {
        start: @settings.business_hours_start,
        end: @settings.business_hours_end
      },
      instructions: "各シナリオをテストするには、対応するstart/endパラメータでupdate_business_hoursエンドポイントを呼び出してください"
    }
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

  # バリデーション強化
  def validate_business_hours_params
    start_hour = params[:business_hours_start].to_i
    end_hour = params[:business_hours_end].to_i
    
    errors = []
    
    # 基本的なバリデーション
    errors << "開始時間は0-23時の間で設定してください" if start_hour < 0 || start_hour > 23
    errors << "終了時間は1-24時の間で設定してください" if end_hour < 1 || end_hour > 24
    errors << "終了時間は開始時間より後に設定してください" if start_hour >= end_hour
    
    # ビジネスロジックのバリデーション
    duration = end_hour - start_hour
    errors << "営業時間は最低4時間以上に設定してください" if duration < 4
    errors << "営業時間は最大16時間以下に設定してください" if duration > 16
    
    # 既存予約との整合性チェック
    conflicting_reservations = Reservation.where(
      "start_time >= ? AND (EXTRACT(hour FROM start_time) < ? OR EXTRACT(hour FROM start_time) >= ?)",
      Date.current.beginning_of_day,
      start_hour,
      end_hour
    )
    
    if conflicting_reservations.exists?
      errors << "新しい営業時間外に#{conflicting_reservations.count}件の予約があります"
    end
    
    errors
  end

  # WebSocket通知の送信
  def broadcast_business_hours_change(old_start, old_end, new_start, new_end)
    if defined?(ActionCable)
      ActionCable.server.broadcast("settings_channel", {
        type: "business_hours_changed",
        start_hour: new_start,
        end_hour: new_end,
        old_start: old_start,
        old_end: old_end,
        changes: calculate_hour_changes(old_start, old_end, new_start, new_end),
        updated_at: @settings.updated_at.iso8601,
        updated_by: current_admin_user&.name || "システム",
        formatted_hours: "#{new_start}:00-#{new_end}:00"
      })
    end
  end

  # 営業時間の変更内容を分析
  def calculate_hour_changes(old_start, old_end, new_start, new_end)
    {
      start_change: new_start - old_start,
      end_change: new_end - old_end,
      duration_change: (new_end - new_start) - (old_end - old_start),
      type: determine_change_type(old_start, old_end, new_start, new_end)
    }
  end

  def determine_change_type(old_start, old_end, new_start, new_end)
    if new_start < old_start && new_end > old_end
      "both_extended"
    elsif new_start > old_start && new_end < old_end
      "both_reduced"
    elsif new_start < old_start
      "morning_extended"
    elsif new_start > old_start
      "morning_reduced"
    elsif new_end > old_end
      "evening_extended"
    elsif new_end < old_end
      "evening_reduced"
    else
      "no_change"
    end
  end
end
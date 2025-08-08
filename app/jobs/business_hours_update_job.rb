class BusinessHoursUpdateJob < ApplicationJob
  queue_as :default

  def perform(setting_id, old_start, old_end, new_start, new_end)
    Rails.logger.info "🔄 Processing business hours update job..."
    
    setting = ApplicationSetting.find(setting_id)
    
    # 関連する予約データの整合性チェック
    affected_reservations = Reservation.where(
      "DATE(start_time) = ? AND (EXTRACT(hour FROM start_time) < ? OR EXTRACT(hour FROM start_time) >= ?)",
      Date.current,
      new_start,
      new_end
    )
    
    if affected_reservations.exists?
      Rails.logger.warn "⚠️ Found #{affected_reservations.count} reservations outside new business hours"
      
      # 管理者に通知（メール送信など）
      # AdminMailer.business_hours_conflict_notification(setting, affected_reservations).deliver_now
    end
    
    # キャッシュの更新
    Rails.cache.delete("business_hours_#{setting.id}")
    Rails.cache.write("business_hours_#{setting.id}", {
      start: new_start,
      end: new_end,
      formatted: "#{new_start}:00-#{new_end}:00"
    }, expires_in: 1.day)
    
    Rails.logger.info "✅ Business hours update job completed"
  end
end 
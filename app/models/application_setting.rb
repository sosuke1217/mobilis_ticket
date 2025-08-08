# app/models/application_setting.rb

class ApplicationSetting < ApplicationRecord
  # バリデーション
  validates :reservation_interval_minutes, 
            presence: true, 
            numericality: { greater_than: 0 }
  validates :business_hours_start, 
            presence: true, 
            numericality: { in: 0..23 }
  validates :business_hours_end, 
            presence: true, 
            numericality: { in: 1..24 }
  validates :slot_interval_minutes, 
            presence: true, 
            numericality: { greater_than: 0 }

  # 現在の設定を取得（安全版）
  def self.current
    first || create_default!
  rescue => e
    Rails.logger.error "❌ ApplicationSetting.current error: #{e.message}"
    create_default!
  end

  # デフォルト設定を作成
  def self.create_default!
    create!(
      reservation_interval_minutes: 15,
      business_hours_start: 10,
      business_hours_end: 20,
      slot_interval_minutes: 30,
      max_advance_booking_days: 30,
      min_advance_booking_hours: 2,
      sunday_closed: true
    )
  rescue => e
    Rails.logger.error "❌ Failed to create default ApplicationSetting: #{e.message}"
    # フォールバック用のオブジェクトを返す
    new(
      reservation_interval_minutes: 15,
      business_hours_start: 10,
      business_hours_end: 20,
      slot_interval_minutes: 30,
      max_advance_booking_days: 30,
      min_advance_booking_hours: 2,
      sunday_closed: true
    )
  end

  # 営業時間の範囲
  def business_hours_range
    "#{business_hours_start}:00-#{business_hours_end}:00"
  end

  # 日曜休業かどうか
  def sunday_closed?
    sunday_closed
  end

  # 営業時間の変更を監視
  after_update :log_business_hours_change, if: :business_hours_changed?
  
  # 営業時間が変更されたかチェック
  def business_hours_changed?
    business_hours_start_changed? || business_hours_end_changed?
  end
  
  # 現在営業中かチェック
  def currently_open?
    current_hour = Time.current.hour
    current_hour >= business_hours_start && current_hour < business_hours_end
  end
  
  # 営業時間の期間を取得
  def business_hours_duration
    business_hours_end - business_hours_start
  end
  
  # フォーマットされた営業時間
  def formatted_business_hours
    "#{business_hours_start.to_s.rjust(2, '0')}:00-#{business_hours_end.to_s.rjust(2, '0')}:00"
  end
  
  # FullCalendar用のbusinessHours設定を生成
  def fullcalendar_business_hours
    {
      startTime: "#{business_hours_start.to_s.rjust(2, '0')}:00",
      endTime: "#{business_hours_end.to_s.rjust(2, '0')}:00",
      daysOfWeek: sunday_closed? ? [1, 2, 3, 4, 5, 6] : [0, 1, 2, 3, 4, 5, 6],
      display: 'inverse-background'
    }
  end

  # キャッシュ付きで営業時間を取得
  def self.cached_business_hours
    Rails.cache.fetch("business_hours_#{first&.id}", expires_in: 1.hour) do
      setting = first || new
      {
        start: setting.business_hours_start || 10,
        end: setting.business_hours_end || 21,
        formatted: setting.formatted_business_hours,
        duration: setting.business_hours_duration,
        fullcalendar: setting.fullcalendar_business_hours
      }
    end
  end
  
  # キャッシュをクリア
  def clear_business_hours_cache
    Rails.cache.delete("business_hours_#{id}")
  end
  
  # 営業時間更新後のコールバック
  after_update :clear_business_hours_cache, if: :business_hours_changed?
  after_update :enqueue_update_job, if: :business_hours_changed?

  private
  
  def business_hours_logic
    if business_hours_start.present? && business_hours_end.present?
      if business_hours_start >= business_hours_end
        errors.add(:business_hours_end, "営業終了時間は開始時間より後に設定してください")
      end
      
      # 営業時間が長すぎる場合の警告
      if business_hours_end - business_hours_start > 16
        errors.add(:base, "営業時間が16時間を超えています。適切な営業時間を設定してください。")
      end
      
      # 営業時間が短すぎる場合の警告
      if business_hours_end - business_hours_start < 4
        errors.add(:base, "営業時間が4時間未満です。十分な営業時間を確保してください。")
      end
    end
  end
  
  def log_business_hours_change
    old_start = business_hours_start_was
    old_end = business_hours_end_was
    
    Rails.logger.info "📝 Business hours changed: #{old_start}:00-#{old_end}:00 → #{business_hours_start}:00-#{business_hours_end}:00"
  end
  
  def enqueue_update_job
    old_start = business_hours_start_was
    old_end = business_hours_end_was
    
    BusinessHoursUpdateJob.perform_later(
      id, 
      old_start, 
      old_end, 
      business_hours_start, 
      business_hours_end
    )
  end
end
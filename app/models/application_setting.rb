# app/models/application_setting.rb

class ApplicationSetting < ApplicationRecord
  validates :reservation_interval_minutes, 
    presence: true, 
    numericality: { 
      greater_than_or_equal_to: 0, 
      less_than_or_equal_to: 60,
      message: "0分から60分の間で設定してください" 
    }
  
  validates :business_hours_start, 
    presence: true, 
    numericality: { 
      greater_than_or_equal_to: 0, 
      less_than: 24,
      message: "0時から23時の間で設定してください"
    }
  
  validates :business_hours_end, 
    presence: true, 
    numericality: { 
      greater_than: :business_hours_start, 
      less_than_or_equal_to: 24,
      message: "営業開始時間より後、24時以前で設定してください"
    }
    
  validates :slot_interval_minutes,
    presence: true,
    inclusion: { 
      in: [10, 15, 30, 60], 
      message: "10, 15, 30, 60分のいずれかを選択してください" 
    }
    
  validates :max_advance_booking_days,
    presence: true,
    numericality: { 
      greater_than: 0, 
      less_than_or_equal_to: 365,
      message: "1日から365日の間で設定してください"
    }
    
  validates :min_advance_booking_hours,
    presence: true,
    numericality: { 
      greater_than_or_equal_to: 0, 
      less_than_or_equal_to: 168,
      message: "0時間から168時間（7日）の間で設定してください"
    }

  # シングルトンパターン（設定は1つだけ）
  def self.current
    first || create_default_settings
  end
  
  def self.create_default_settings
    create!(
      reservation_interval_minutes: 15,
      business_hours_start: 10,
      business_hours_end: 20,
      slot_interval_minutes: 30,
      max_advance_booking_days: 30,
      min_advance_booking_hours: 24,
      sunday_closed: true
    )
  end
  
  # 営業時間の表示用
  def business_hours_range
    "#{business_hours_start}:00-#{business_hours_end}:00"
  end
  
  # 環境変数との統合（後方互換性）
  def self.reservation_interval_minutes
    if table_exists? && current
      current.reservation_interval_minutes
    else
      ENV.fetch('RESERVATION_INTERVAL_MINUTES', 15).to_i
    end
  end
  
  def self.business_hours_start_time
    if table_exists? && current
      current.business_hours_start
    else
      ENV.fetch('BUSINESS_HOURS_START', '10:00')
    end
  end
  
  def self.business_hours_end_time
    if table_exists? && current
      current.business_hours_end
    else
      ENV.fetch('BUSINESS_HOURS_END', '20:00')
    end
  end
  
  # 営業日かどうかチェック
  def business_day?(date)
    return false if sunday_closed? && date.sunday?
    # 他の休業日ロジックもここに追加可能
    true
  end
  
  # 営業時間内かチェック
  def within_business_hours?(time)
    hour = time.hour
    hour >= business_hours_start && hour < business_hours_end
  end
  
  # デバッグ用
  def to_debug_hash
    {
      reservation_interval_minutes: reservation_interval_minutes,
      business_hours: business_hours_range,
      slot_interval_minutes: slot_interval_minutes,
      max_advance_booking_days: max_advance_booking_days,
      min_advance_booking_hours: min_advance_booking_hours,
      sunday_closed: sunday_closed?
    }
  end
end
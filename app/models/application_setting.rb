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
      min_advance_booking_hours: 24,
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
      min_advance_booking_hours: 24,
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
end
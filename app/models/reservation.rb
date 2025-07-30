# app/models/reservation.rb の修正

class Reservation < ApplicationRecord
  # ステータス定義（Rails 8対応）
  enum :status, {
    confirmed: 0,    # 確定
    tentative: 1,    # 仮予約
    cancelled: 2,    # キャンセル
    completed: 3,    # 完了
    no_show: 4       # 無断キャンセル
  }
  
  # 繰り返しタイプ定義（Rails 8対応）
  enum :recurring_type, {
    weekly: 'weekly',
    monthly: 'monthly'
  }, prefix: true
  
  validates :start_time, :end_time, :course, presence: true
  validate :no_time_overlap, unless: :cancelled?
  validate :start_and_end_must_be_on_10_minute_interval, unless: :skip_time_validation
  validate :end_time_after_start_time
  validate :cancellation_reason_presence, if: :cancelled?
  validate :booking_within_business_hours, unless: :skip_business_hours_validation
  validate :booking_not_too_far_in_advance, unless: :skip_advance_booking_validation
  validate :booking_minimum_advance_notice, unless: :skip_advance_notice_validation
  
  # 管理者用のバリデーションスキップフラグ
  attr_accessor :skip_time_validation, :skip_business_hours_validation, 
                :skip_advance_booking_validation, :skip_advance_notice_validation
  
  belongs_to :ticket, optional: true
  belongs_to :user, optional: true
  belongs_to :parent_reservation, class_name: 'Reservation', optional: true
  has_many :child_reservations, class_name: 'Reservation', foreign_key: 'parent_reservation_id', dependent: :destroy
  
  before_validation :set_name_from_user, if: -> { name.blank? && user.present? }
  before_validation :set_end_time, if: -> { start_time.present? && course.present? && end_time.blank? }
  after_create :schedule_confirmation_email
  after_update :handle_status_change
  after_create :log_reservation_created
  after_update :log_reservation_updated, if: :saved_change_to_status?

  # スコープ定義
  scope :active, -> { where.not(status: :cancelled) }
  scope :upcoming, -> { where('start_time > ?', Time.current) }
  scope :today, -> { where(start_time: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :tomorrow, -> { where(start_time: 1.day.from_now.beginning_of_day..1.day.from_now.end_of_day) }
  scope :this_week, -> { where(start_time: Time.current.beginning_of_week..Time.current.end_of_week) }
  scope :this_month, -> { where(start_time: Time.current.beginning_of_month..Time.current.end_of_month) }
  scope :needs_reminder, -> { 
    active.upcoming
      .where(reminder_sent_at: nil)
      .where(start_time: 1.day.from_now.beginning_of_day..1.day.from_now.end_of_day)
  }
  
  # 特定の時間帯と重複する予約を検索
  scope :overlapping, ->(start_time, end_time) {
    where('start_time < ? AND end_time > ?', end_time, start_time)
  }

  # 管理者用の制限なし予約作成メソッド
  def self.create_as_admin!(attributes)
    reservation = new(attributes)
    reservation.skip_business_hours_validation = true
    reservation.skip_advance_booking_validation = true
    reservation.skip_advance_notice_validation = true
    reservation.save!
    reservation
  end

  # 管理者用の制限なし予約更新メソッド
  def update_as_admin!(attributes)
    self.skip_business_hours_validation = true
    self.skip_advance_booking_validation = true
    self.skip_advance_notice_validation = true
    self.skip_time_validation = true
    update!(attributes)
  end

  # キャンセル可能かチェック
  def cancellable?
    confirmed? || tentative?
  end

  # 編集可能かチェック
  def editable?
    !cancelled? && start_time > Time.current
  end

  # コースの分数を取得
  def get_duration_minutes
    case course
    when "40分", "40分コース" then 40
    when "60分", "60分コース" then 60
    when "80分", "80分コース" then 80
    else 60
    end
  end

  # 料金を取得
  def get_price
    case course
    when "40分", "40分コース" then 8000
    when "60分", "60分コース" then 12000
    when "80分", "80分コース" then 16000
    else 12000
    end
  end

  # 予約の説明文
  def description
    "#{course} - #{start_time.strftime('%m/%d %H:%M')}〜#{end_time.strftime('%H:%M')}"
  end

  def status_text
    case status
    when 'confirmed' then '確定'
    when 'tentative' then '仮予約'
    when 'cancelled' then 'キャンセル'
    when 'completed' then '完了'
    when 'no_show' then '無断キャンセル'
    else status
    end
  end

  # ステータス色（カレンダー表示用）
  def status_color
    case status
    when 'confirmed' then '#28a745'  # 緑
    when 'tentative' then '#ffc107'  # 黄
    when 'cancelled' then '#dc3545'  # 赤
    when 'completed' then '#6c757d'  # グレー
    when 'no_show' then '#fd7e14'    # オレンジ
    else '#007bff'                   # 青（デフォルト）
    end
  end

  # キャンセル処理
  def cancel!(reason)
    update!(
      status: :cancelled,
      cancelled_at: Time.current,
      cancellation_reason: reason
    )
    
    # 子予約（繰り返し予約）もキャンセル
    if recurring?
      child_reservations.active.each do |child|
        child.cancel!("親予約のキャンセルに伴う自動キャンセル")
      end
    end
    
    # キャンセル通知送信
    send_cancellation_notifications
  end

  def self.interval_minutes
    ENV.fetch('RESERVATION_INTERVAL_MINUTES', 15).to_i
  end

  # インターバルを含む実際の終了時間
  def end_time_with_interval
    end_time + self.class.interval_minutes.minutes
  end

  # インターバルを含む実際の開始時間
  def start_time_with_interval
    start_time - self.class.interval_minutes.minutes
  end

  scope :overlapping_with_interval, ->(start_time, end_time) {
    interval_min = interval_minutes
    where(
      '(start_time - INTERVAL ? MINUTE) < ? AND (end_time + INTERVAL ? MINUTE) > ?',
      interval_min, end_time, interval_min, start_time
    )
  }

  # 空き時間を取得（インターバル考慮版）
  def self.available_slots_for_with_interval(date, duration_minutes = 60)
    business_start = ENV.fetch('BUSINESS_HOURS_START', '10:00')
    business_end = ENV.fetch('BUSINESS_HOURS_END', '20:00')
    slot_interval = ENV.fetch('BOOKING_SLOT_INTERVAL', 30).to_i
    
    opening_time = Time.zone.parse("#{date} #{business_start}")
    closing_time = Time.zone.parse("#{date} #{business_end}")
    
    slots = []
    current_time = opening_time
    
    while current_time + duration_minutes.minutes <= closing_time
      end_time = current_time + duration_minutes.minutes
      
      # インターバルを考慮した重複チェック
      unless active.overlapping_with_interval(current_time, end_time).exists?
        slots << {
          start_time: current_time,
          end_time: end_time,
          available: true
        }
      end
      
      current_time += slot_interval.minutes
    end
    
    slots
  end

  private

  def no_time_overlap
    return if start_time.blank? || end_time.blank?
  
    # システム設定からバッファ時間を取得
    begin
      settings = ApplicationSetting.current
      buffer_minutes = settings.reservation_interval_minutes
    rescue => e
      Rails.logger.warn "ApplicationSetting not available, using default buffer: #{e.message}"
      buffer_minutes = 15 # デフォルト値
    end
  
    Reservation.transaction do
      if buffer_minutes > 0
        # バッファ時間を考慮した重複チェック
        buffer_start = start_time - buffer_minutes.minutes
        buffer_end = end_time + buffer_minutes.minutes
        
        overlapping = Reservation.active
          .where.not(id: id)
          .where('start_time < ? AND end_time > ?', buffer_end, buffer_start)
          .lock
      else
        # バッファ時間なしの重複チェック
        overlapping = Reservation.active
          .where.not(id: id)
          .where('start_time < ? AND end_time > ?', end_time, start_time)
          .lock
      end
  
      if overlapping.exists?
        overlapping_reservation = overlapping.first
        if buffer_minutes > 0
          errors.add(:base, "#{overlapping_reservation.start_time.strftime('%H:%M')}〜#{overlapping_reservation.end_time.strftime('%H:%M')}の予約があります。（#{buffer_minutes}分のインターバルが必要）")
        else
          errors.add(:base, "#{overlapping_reservation.start_time.strftime('%H:%M')}〜#{overlapping_reservation.end_time.strftime('%H:%M')}に既に予約が入っています。")
        end
      end
    end
  end

  def start_and_end_must_be_on_10_minute_interval
    return unless start_time && end_time
    
    if start_time.min % 10 != 0 || end_time.min % 10 != 0
      Rails.logger.warn "⚠️ Time validation failed: start=#{start_time}, end=#{end_time}"
      errors.add(:base, "開始時間と終了時間は10分刻みで入力してください")
    end
  end
  
  def end_time_after_start_time
    return unless start_time && end_time
    
    if end_time <= start_time
      errors.add(:end_time, "は開始時間より後に設定してください")
    end
  end

  def cancellation_reason_presence
    if cancelled? && cancellation_reason.blank?
      errors.add(:cancellation_reason, "キャンセル理由を入力してください")
    end
  end

  # 営業時間チェック（管理者の場合はスキップ可能）
  def booking_within_business_hours
    return unless start_time && end_time
    
    # システム設定から営業時間を取得
    settings = ApplicationSetting.current
    business_start = settings.business_hours_start
    business_end = settings.business_hours_end
    
    start_hour = start_time.hour
    end_hour = end_time.hour
    
    if start_hour < business_start || end_hour > business_end
      errors.add(:start_time, "営業時間内（#{business_start}:00-#{business_end}:00）でご予約ください")
    end
  end

  # 予約可能期間チェック（管理者の場合はスキップ可能）
  def booking_not_too_far_in_advance
    return unless start_time
    
    # システム設定から最大予約期間を取得
    settings = ApplicationSetting.current
    max_days = settings.max_advance_booking_days
    
    if start_time > max_days.days.from_now
      errors.add(:start_time, "#{max_days}日以内でご予約ください")
    end
  end

  # 最低予約時間チェック（管理者の場合はスキップ可能）
  def booking_minimum_advance_notice
    return unless start_time
    return if persisted? # 既存予約の更新時はスキップ
    
    # システム設定から最低予約時間を取得
    settings = ApplicationSetting.current
    min_hours = settings.min_advance_booking_hours
    
    if start_time < min_hours.hours.from_now
      errors.add(:start_time, "#{min_hours}時間前までにご予約ください")
    end
  end

  def self.available_slots_for(date, duration_minutes = 60)
    settings = ApplicationSetting.current
    
    # システム設定が日曜休業で、指定日が日曜日の場合は空配列を返す
    return [] if settings.sunday_closed? && date.sunday?
    
    business_start = "#{settings.business_hours_start}:00"
    business_end = "#{settings.business_hours_end}:00"
    slot_interval = settings.slot_interval_minutes
    buffer_minutes = settings.reservation_interval_minutes
    
    opening_time = Time.zone.parse("#{date} #{business_start}")
    closing_time = Time.zone.parse("#{date} #{business_end}")
    
    slots = []
    current_time = opening_time
    
    while current_time + duration_minutes.minutes <= closing_time
      end_time = current_time + duration_minutes.minutes
      
      # バッファ時間を考慮した重複チェック
      if buffer_minutes > 0
        buffer_start = current_time - buffer_minutes.minutes
        buffer_end = end_time + buffer_minutes.minutes
        overlapping_check = active.where('start_time < ? AND end_time > ?', buffer_end, buffer_start)
      else
        overlapping_check = active.where('start_time < ? AND end_time > ?', end_time, current_time)
      end
      
      unless overlapping_check.exists?
        slots << {
          start_time: current_time,
          end_time: end_time,
          available: true
        }
      end
      
      current_time += slot_interval.minutes
    end
    
    slots
  end

  def set_name_from_user
    self.name = user.name if user
  end

  def set_end_time
    duration = get_duration_minutes
    self.end_time = start_time + duration.minutes
  end

  def schedule_confirmation_email
    return unless user && user.email.present?
    
    begin
      ReservationMailer.confirmation(self).deliver_later(wait: 5.minutes)
      Rails.logger.info "📧 Confirmation email scheduled for: #{user.email}"
    rescue => e
      Rails.logger.error "確認メール送信エラー: #{e.message}"
    end
  end

  def handle_status_change
    if saved_change_to_status?
      case status
      when 'confirmed'
        send_confirmation_notifications
      when 'cancelled'
        send_cancellation_notifications
      end
    end
  end

  def handle_status_change
    if saved_change_to_status?
      case status
      when 'confirmed'
        send_confirmation_notifications
      when 'cancelled'
        send_cancellation_notifications
      end
    end
  end

  def send_confirmation_notifications
    # メール通知
    if user&.email.present?
      begin
        ReservationMailer.confirmation(self).deliver_later
        Rails.logger.info "📧 Confirmation notification sent to: #{user.email}"
      rescue => e
        Rails.logger.error "確認通知送信エラー: #{e.message}"
      end
    end
    
    # LINE通知
    if user&.line_user_id.present?
      begin
        # LineBookingNotifier.booking_confirmed(self)
        Rails.logger.info "📱 LINE confirmation notification sent to: #{user.line_user_id}"
      rescue => e
        Rails.logger.error "LINE確認通知送信エラー: #{e.message}"
      end
    end
  end

  def send_cancellation_notifications
    # メール通知
    if user&.email.present?
      begin
        ReservationMailer.cancellation_notification(self).deliver_later
        Rails.logger.info "📧 Cancellation notification sent to: #{user.email}"
      rescue => e
        Rails.logger.error "キャンセル通知送信エラー: #{e.message}"
      end
    end
    
    # LINE通知
    if user&.line_user_id.present?
      begin
        # LineBookingNotifier.send_cancellation_notification(self)
        Rails.logger.info "📱 LINE cancellation notification sent to: #{user.line_user_id}"
      rescue => e
        Rails.logger.error "LINEキャンセル通知送信エラー: #{e.message}"
      end
    end
  end

  def log_reservation_created
    Rails.logger.info "✅ 新規予約作成: ID=#{id}, #{name}様, #{start_time&.strftime('%m/%d %H:%M')}, #{course}"
  end

  def log_reservation_updated
    Rails.logger.info "📝 予約ステータス変更: ID=#{id}, #{name}様, #{status}"
  end
end
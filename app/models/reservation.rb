# app/models/reservation.rb の強化版

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
  validate :booking_within_business_hours
  validate :booking_not_too_far_in_advance
  validate :booking_minimum_advance_notice
  
  # 一時的にバリデーションをスキップするためのアクセサー
  attr_accessor :skip_time_validation
  
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

  # 🆕 営業時間チェック
  def booking_within_business_hours
    return unless start_time && end_time
    
    business_start = ENV.fetch('BUSINESS_HOURS_START', '10:00')
    business_end = ENV.fetch('BUSINESS_HOURS_END', '20:00')
    
    start_hour_min = start_time.strftime('%H:%M')
    end_hour_min = end_time.strftime('%H:%M')
    
    if start_hour_min < business_start || end_hour_min > business_end
      errors.add(:start_time, "営業時間内（#{business_start}-#{business_end}）でご予約ください")
    end
  end

  # 🆕 予約可能期間チェック
  def booking_not_too_far_in_advance
    return unless start_time
    
    max_days = ENV.fetch('MAX_ADVANCE_BOOKING_DAYS', 30).to_i
    if start_time > max_days.days.from_now
      errors.add(:start_time, "#{max_days}日以内でご予約ください")
    end
  end

  # 🆕 最低予約時間チェック
  def booking_minimum_advance_notice
    return unless start_time
    return if persisted? # 既存予約の更新時はスキップ
    
    min_hours = ENV.fetch('MIN_ADVANCE_BOOKING_HOURS', 24).to_i
    if start_time < min_hours.hours.from_now
      errors.add(:start_time, "#{min_hours}時間前までにご予約ください")
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

  # 🆕 キャンセル可能期間チェック
  def cancellable_until
    # 開始時間の24時間前まで
    start_time - 24.hours
  end

  def can_cancel_online?
    return false unless cancellable?
    Time.current < cancellable_until
  end

  # 予約をキャンセル
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

  # 🆕 キャンセル通知送信
  def send_cancellation_notifications
    # メール通知
    if user&.email.present?
      ReservationMailer.cancellation_notification(self).deliver_later
    end
    
    # LINE通知
    if user&.line_user_id.present?
      LineBookingNotifier.send_cancellation_notification(self)
    end
  end

  # 予約確定
  def confirm!
    update!(status: :confirmed)
    send_confirmation_notifications
  end

  # 🆕 確定通知送信
  def send_confirmation_notifications
    # メール通知
    if user&.email.present?
      ReservationMailer.confirmation(self).deliver_later
    end
    
    # LINE通知
    if user&.line_user_id.present?
      LineBookingNotifier.booking_confirmed(self)
    end
  end

  # 予約完了
  def complete!
    update!(status: :completed)
    
    # 完了通知送信
    if user&.email.present?
      ReservationMailer.completion_notification(self).deliver_later
    end
  end

  # 無断キャンセル
  def mark_no_show!
    update!(status: :no_show)
  end

  # 🆕 予約時間の変更
  def reschedule!(new_start_time, new_end_time = nil)
    # 新しい終了時間が指定されていない場合は、コースから計算
    unless new_end_time
      duration = get_duration_minutes
      new_end_time = new_start_time + duration.minutes
    end
    
    # 重複チェック
    overlapping = Reservation.active
      .where.not(id: id)
      .overlapping(new_start_time, new_end_time)
    
    if overlapping.exists?
      errors.add(:base, "指定された時間には既に予約が入っています")
      return false
    end
    
    update!(
      start_time: new_start_time,
      end_time: new_end_time
    )
    
    # 変更通知送信
    send_reschedule_notifications
    true
  end

  # 🆕 時間変更通知
  def send_reschedule_notifications
    # TODO: 予約変更通知メールの実装
    Rails.logger.info "予約時間変更: #{name}様 - #{start_time.strftime('%m/%d %H:%M')}"
  end

  # 繰り返し予約作成
  def create_recurring_reservations!
    return unless recurring? && recurring_until.present?
    
    case recurring_type
    when 'weekly'
      create_weekly_reservations
    when 'monthly'
      create_monthly_reservations
    end
  end

  # ステータス表示用
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

  # ステータス色
  def status_color
    case status
    when 'confirmed' then '#28a745'  # 緑
    when 'tentative' then '#ffc107'  # 黄
    when 'cancelled' then '#dc3545'  # 赤
    when 'completed' then '#6c757d'  # グレー
    when 'no_show' then '#fd7e14'    # オレンジ
    else '#007bff'                   # 青
    end
  end

  # キャンセル可能かチェック
  def cancellable?
    confirmed? || tentative?
  end

  # 編集可能かチェック
  def editable?
    !cancelled? && start_time > Time.current
  end

  # 🆕 コースの分数を取得
  def get_duration_minutes
    case course
    when "40分", "40分コース" then 40
    when "60分", "60分コース" then 60
    when "80分", "80分コース" then 80
    else 60
    end
  end

  # 🆕 料金を取得
  def get_price
    case course
    when "40分", "40分コース" then 8000
    when "60分", "60分コース" then 12000
    when "80分", "80分コース" then 16000
    else 12000
    end
  end

  # 🆕 予約の説明文
  def description
    "#{course} - #{start_time.strftime('%m/%d %H:%M')}〜#{end_time.strftime('%H:%M')}"
  end

  # 🆕 Google Calendar用の説明
  def google_calendar_description
    desc = "【Mobilis Stretch 予約】\n\n"
    desc += "コース: #{course}\n"
    desc += "お客様: #{name}\n"
    desc += "住所: #{user&.address}\n" if user&.address.present?
    desc += "電話: #{user&.phone_number}\n" if user&.phone_number.present?
    desc += "メモ: #{note}\n" if note.present?
    desc += "\nステータス: #{status_text}"
    desc
  end

  # 🆕 空き時間を取得（クラスメソッド）
  def self.available_slots_for(date, duration_minutes = 60)
    business_start = ENV.fetch('BUSINESS_HOURS_START', '10:00')
    business_end = ENV.fetch('BUSINESS_HOURS_END', '20:00')
    slot_interval = ENV.fetch('BOOKING_SLOT_INTERVAL', 30).to_i
    
    opening_time = Time.zone.parse("#{date} #{business_start}")
    closing_time = Time.zone.parse("#{date} #{business_end}")
    
    slots = []
    current_time = opening_time
    
    while current_time + duration_minutes.minutes <= closing_time
      end_time = current_time + duration_minutes.minutes
      
      # アクティブな予約との重複チェック
      unless active.overlapping(current_time, end_time).exists?
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

  # 🆕 日別の空き状況を取得
  def self.availability_for_date_range(start_date, end_date, duration_minutes = 60)
    availability = {}
    
    (start_date..end_date).each do |date|
      # 日曜日は休業日と仮定
      next if date.sunday?
      
      slots = available_slots_for(date, duration_minutes)
      availability[date] = {
        total_slots: slots.count,
        available_slots: slots.select { |slot| slot[:available] }.count,
        utilization_rate: slots.any? ? (slots.reject { |slot| slot[:available] }.count.to_f / slots.count * 100).round(1) : 0
      }
    end
    
    availability
  end

  private

  def no_time_overlap
    return if start_time.blank? || end_time.blank?

    overlapping = Reservation.active
      .where.not(id: id)
      .overlapping(start_time, end_time)

    if overlapping.exists?
      errors.add(:base, "この時間帯にはすでに予約が入っています。")
    end
  end

  def set_name_from_user
    if user.present? && user.name.present?
      self.name = user.name
    elsif name.blank?
      self.name = "予約者未設定"
    end
  end

  def set_end_time
    return if skip_time_validation
    
    self.end_time ||= start_time + get_duration_minutes.minutes
  end

  def schedule_confirmation_email
    return unless user&.email.present?
    
    ReservationMailer.confirmation(self).deliver_later
    update_column(:confirmation_sent_at, Time.current)
  end

  def handle_status_change
    if saved_change_to_status?
      case status
      when 'cancelled'
        # キャンセル通知は cancel! メソッドで送信済み
      when 'confirmed'
        send_confirmation_notifications
      when 'completed'
        # 完了メール送信済み
      end
    end
  end

  def log_reservation_created
    Rails.logger.info "📅 新規予約作成: #{name} - #{start_time.strftime('%m/%d %H:%M')} (#{status})"
  end

  def log_reservation_updated
    Rails.logger.info "📅 予約ステータス更新: #{name} - #{status_was} → #{status}"
  end

  def create_weekly_reservations
    current_date = start_time + 1.week
    
    while current_date.to_date <= recurring_until
      child_reservations.create!(
        name: name,
        start_time: current_date,
        end_time: current_date + (end_time - start_time),
        course: course,
        note: note,
        user: user,
        ticket: ticket,
        status: status
      )
      current_date += 1.week
    end
  end

  def create_monthly_reservations
    current_date = start_time + 1.month
    
    while current_date.to_date <= recurring_until
      child_reservations.create!(
        name: name,
        start_time: current_date,
        end_time: current_date + (end_time - start_time),
        course: course,
        note: note,
        user: user,
        ticket: ticket,
        status: status
      )
      current_date += 1.month
    end
  end
end
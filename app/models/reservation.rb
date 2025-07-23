class Reservation < ApplicationRecord
  # ステータス定義
  enum status: {
    confirmed: 0,    # 確定
    tentative: 1,    # 仮予約
    cancelled: 2,    # キャンセル
    completed: 3,    # 完了
    no_show: 4       # 無断キャンセル
  }
  
  # 繰り返しタイプ定義
  enum recurring_type: {
    weekly: 'weekly',
    monthly: 'monthly'
  }, _prefix: true
  
  validates :name, :start_time, :end_time, :course, presence: true
  validate :no_time_overlap, unless: :cancelled?
  validate :start_and_end_must_be_on_10_minute_interval
  validate :end_time_after_start_time
  validate :cancellation_reason_presence, if: :cancelled?
  
  belongs_to :ticket, optional: true
  belongs_to :user, optional: true
  belongs_to :parent_reservation, class_name: 'Reservation', optional: true
  has_many :child_reservations, class_name: 'Reservation', foreign_key: 'parent_reservation_id', dependent: :destroy
  
  before_validation :set_end_time, if: -> { start_time.present? && course.present? && end_time.blank? }
  after_create :schedule_confirmation_email
  after_update :handle_status_change

  # スコープ定義
  scope :active, -> { where.not(status: :cancelled) }
  scope :upcoming, -> { where('start_time > ?', Time.current) }
  scope :today, -> { where(start_time: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :this_week, -> { where(start_time: Time.current.beginning_of_week..Time.current.end_of_week) }

  def start_and_end_must_be_on_10_minute_interval
    return unless start_time && end_time
    
    if start_time.min % 10 != 0 || end_time.min % 10 != 0
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
    
    # キャンセルメール送信
    ReservationMailer.cancellation_notification(self).deliver_later if user&.email.present?
  end

  # 予約完了
  def complete!
    update!(status: :completed)
  end

  # 無断キャンセル
  def mark_no_show!
    update!(status: :no_show)
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

  def self.available_slots_for(date)
    opening_time = Time.zone.parse("#{date} 10:00")
    closing_time = Time.zone.parse("#{date} 20:00")
    slot_length = 60.minutes
  
    slots = []
    while opening_time + slot_length <= closing_time
      end_time = opening_time + slot_length
      # アクティブな予約のみチェック
      overlap = active.where("start_time < ? AND end_time > ?", end_time, opening_time).exists?
      slots << opening_time unless overlap
      opening_time += slot_length
    end
    slots
  end
  
  # スコープとアクセサー
  attr_accessor :skip_course_validation
  
  private

  def no_time_overlap
    return if start_time.blank? || end_time.blank?

    overlapping = Reservation.active  # キャンセルされた予約は除外
      .where.not(id: id)
      .where('start_time < ? AND end_time > ?', end_time, start_time)

    if overlapping.exists?
      errors.add(:base, "この時間帯にはすでに予約が入っています。")
    end
  end

  def set_end_time
    return if skip_course_validation
    
    self.end_time ||= begin
      duration = case course
                 when "40分" then 40
                 when "60分" then 60
                 when "80分" then 80
                 else 60
                 end
      start_time + duration.minutes
    end
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
      when 'completed'
        # 完了メール送信
        ReservationMailer.completion_notification(self).deliver_later if user&.email.present?
      end
    end
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
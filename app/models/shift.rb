class Shift < ApplicationRecord
  validates :date, presence: true
  validates :shift_type, presence: true, inclusion: { in: %w[normal extended shortened closed custom] }
  validates :start_time, presence: true, if: :requires_time?
  validates :end_time, presence: true, if: :requires_time?
  validate :end_time_after_start_time, if: :requires_time?
  validate :breaks_within_business_hours, if: :requires_time?

  scope :for_date, ->(date) { where(date: date) }
  scope :upcoming, -> { where('date >= ?', Date.current).order(:date) }
  scope :recent, -> { where('date >= ?', Date.current - 30.days).order(:date) }

  def requires_time?
    %w[extended shortened custom].include?(shift_type)
  end

  def business_hours
    return nil unless requires_time?
    "#{start_time.strftime('%H:%M')} - #{end_time.strftime('%H:%M')}"
  end

  def business_hours_duration
    return nil unless requires_time?
    duration = (end_time - start_time) / 1.hour
    "#{duration.to_i}時間"
  end

  def breaks_display
    return "なし" if breaks.blank?
    breaks.map { |break_time| "#{break_time['start']}-#{break_time['end']}" }.join(", ")
  end

  def shift_type_display
    case shift_type
    when 'normal'
      '通常営業'
    when 'extended'
      '営業時間延長'
    when 'shortened'
      '営業時間短縮'
    when 'closed'
      '営業休止'
    when 'custom'
      'カスタム時間'
    else
      shift_type
    end
  end

  def shift_type_badge_class
    case shift_type
    when 'normal'
      'bg-success'
    when 'extended'
      'bg-warning'
    when 'shortened'
      'bg-info'
    when 'closed'
      'bg-danger'
    when 'custom'
      'bg-primary'
    else
      'bg-secondary'
    end
  end

  def as_json_with_display
    {
      id: id,
      date: date,
      date_display: date.strftime('%m月%d日'),
      weekday: date.strftime('(%a)'),
      shift_type: shift_type,
      shift_type_display: shift_type_display,
      shift_type_badge_class: shift_type_badge_class,
      start_time: start_time&.strftime('%H:%M'),
      end_time: end_time&.strftime('%H:%M'),
      business_hours: business_hours,
      business_hours_duration: business_hours_duration,
      breaks: breaks,
      breaks_display: breaks_display,
      notes: notes,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  private

  def end_time_after_start_time
    return unless start_time && end_time
    if end_time <= start_time
      errors.add(:end_time, 'は開始時間より後に設定してください')
    end
  end

  def breaks_within_business_hours
    return unless breaks.present? && start_time && end_time
    breaks.each_with_index do |break_time, index|
      break_start = Time.parse(break_time['start'])
      break_end = Time.parse(break_time['end'])
      
      if break_start < start_time || break_end > end_time
        errors.add(:breaks, "休憩時間#{index + 1}は営業時間内に設定してください")
      end
      
      if break_end <= break_start
        errors.add(:breaks, "休憩時間#{index + 1}の終了時間は開始時間より後に設定してください")
      end
    end
  end
end

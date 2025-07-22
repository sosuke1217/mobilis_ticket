class Reservation < ApplicationRecord
  validates :name, :start_time, :end_time, :course, presence: true
  validate :no_time_overlap

  before_validation :set_end_time, if: -> { start_time.present? && course.present? && end_time.blank? }
  validate :start_and_end_must_be_on_10_minute_interval

  def start_and_end_must_be_on_10_minute_interval
    if start_time.min % 10 != 0 || end_time.min % 10 != 0
      errors.add(:base, "開始時間と終了時間は10分刻みで入力してください")
    end
  end

  private

  def self.available_slots_for(date)
    opening_time = Time.zone.parse("#{date} 10:00")
    closing_time = Time.zone.parse("#{date} 20:00")
    slot_length = 60.minutes
  
    slots = []
    while opening_time + slot_length <= closing_time
      end_time = opening_time + slot_length
      overlap = Reservation.where("start_time < ? AND end_time > ?", end_time, opening_time).exists?
      slots << opening_time unless overlap
      opening_time += slot_length
    end
    slots
  end
  
  def no_time_overlap
    return if start_time.blank? || end_time.blank?

    overlapping = Reservation
      .where.not(id: id)
      .where('start_time < ? AND end_time > ?', end_time, start_time)

    if overlapping.exists?
      errors.add(:base, "この時間帯にはすでに予約が入っています。")
    end
  end

  def set_end_time
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
end

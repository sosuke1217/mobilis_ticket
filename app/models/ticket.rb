class Ticket < ApplicationRecord
  belongs_to :user
  belongs_to :ticket_template
  has_many :ticket_usages, dependent: :destroy

  validates :ticket_template_id, presence: true
  validates :total_count, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :remaining_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :purchase_date, presence: true
  validates :expiry_date, presence: true

  validate :remaining_count_not_exceed_total_count
  validate :expiry_after_purchase_date

  def usable?
    remaining_count > 0 && (expiry_date.nil? || expiry_date > Time.current)
  end

  def use_one
    with_lock do
      if usable?
        self.remaining_count -= 1
        save
      else
        false
      end
    end
  end

   # Atomically consume one ticket and record the usage
   def consume_one(note: nil, used_at: Time.current)
    with_lock do
      return false unless usable?

      transaction do
        self.remaining_count -= 1
        save!
        ticket_usages.create!(user: user, used_at: used_at, note: note)
      end
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[id ticket_template_id user_id remaining_count created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[ticket_template user]
  end

  def unit_price
    return nil unless ticket_template&.price && ticket_template&.total_count.to_i > 0
    ticket_template.price.to_f / ticket_template.total_count
  end

  scope :active, -> {
    where("remaining_count > 0 AND expiry_date >= ?", Date.today)
  }

  scope :used_up, -> {
    where("remaining_count = 0")
  }

  private

  def remaining_count_not_exceed_total_count
    if remaining_count.present? && total_count.present? && remaining_count > total_count
      errors.add(:remaining_count, "は総回数を超えることはできません")
    end
  end

  def expiry_after_purchase_date
    if purchase_date.present? && expiry_date.present? && expiry_date < purchase_date
      errors.add(:expiry_date, "は購入日以降の日付にしてください")
    end
  end
end

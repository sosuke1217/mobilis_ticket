class TicketTemplate < ApplicationRecord
  validates :name, presence: true, length: { maximum: 100 }
  validates :total_count, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :price, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :expiry_days, presence: true, numericality: { greater_than: 0 }

  def self.ransackable_attributes(auth_object = nil)
    %w[id name total_count price expiry_days created_at updated_at]
  end
end

class TicketTemplate < ApplicationRecord
  validates :expiry_days, presence: true, numericality: { greater_than: 0 }

  def self.ransackable_attributes(auth_object = nil)
    %w[id name created_at updated_at]
  end
end

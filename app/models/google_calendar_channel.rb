class GoogleCalendarChannel < ApplicationRecord
  validates :channel_id, presence: true, uniqueness: true
  validates :resource_id, presence: true
  validates :expiration, presence: true
  validates :webhook_url, presence: true
  
  scope :active, -> { where('expiration > ?', Time.current) }
  scope :expired, -> { where('expiration <= ?', Time.current) }
  
  def expired?
    expiration <= Time.current
  end
end


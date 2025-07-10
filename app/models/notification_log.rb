class NotificationLog < ApplicationRecord
  belongs_to :user
  belongs_to :ticket

  def self.ransackable_attributes(auth_object = nil)
    %w[kind sent_at message]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[user ticket]
  end
end

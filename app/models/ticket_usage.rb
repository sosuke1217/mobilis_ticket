# app/models/ticket_usage.rb
class TicketUsage < ApplicationRecord
  belongs_to :ticket
  belongs_to :user

  validates :used_at, presence: true
  validate :used_at_cannot_be_in_future
  validates :note, length: { maximum: 1000 }, allow_blank: true

  # 🔽 ticket_title 用の ransacker（JOINではなくサブクエリ）
  ransacker :ticket_title do
    Arel.sql("(SELECT title FROM tickets WHERE tickets.id = ticket_usages.ticket_id)")
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[id ticket_id user_id used_at created_at updated_at ticket_title]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[ticket user]
  end

  private

  def used_at_cannot_be_in_future
    if used_at.present? && used_at > Time.zone.now
      errors.add(:used_at, "は未来の日付にできません")
    end
  end
end

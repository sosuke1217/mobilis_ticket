class User < ApplicationRecord
  has_many :tickets, dependent: :destroy
  has_many :ticket_usages
  has_one :notification_preference, dependent: :destroy
  after_create :build_default_notification_preference
  

  def build_default_notification_preference
    create_notification_preference!(enabled: true)
  end
  
  def admin?
    admin
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[id name line_user_id created_at updated_at admin]
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end

  # ✅ 残チケット枚数の合計
  def active_ticket_count
    tickets.sum(:remaining_count)
  end

  # ✅ 最終来店日（最新の使用履歴）
  def last_usage_date
    ticket_usages.order(used_at: :desc).limit(1).pluck(:used_at).first
  end

  # ユーザーの未使用分のチケット金額（残額合計）
  def remaining_ticket_value
    tickets.includes(:ticket_template).sum do |ticket|
      next 0 unless ticket.unit_price && ticket.remaining_count
      ticket.unit_price * ticket.remaining_count
    end
  end
end

class User < ApplicationRecord
  has_many :tickets, dependent: :destroy
  has_many :ticket_usages, through: :tickets, dependent: :destroy
  has_many :reservations, dependent: :nullify  # 予約は削除せずuser_idをnullに
  has_one :notification_preference, dependent: :destroy
  has_many :notification_logs, dependent: :destroy
  
  # バリデーション
  validates :name, presence: true, length: { maximum: 100 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone_number, format: { with: /\A[\d\-\(\)\s]+\z/ }, allow_blank: true
  validates :postal_code, format: { with: /\A\d{3}-?\d{4}\z/ }, allow_blank: true
  
  after_create :build_default_notification_preference
  
  # 削除前のバリデーション（必要に応じて）
  before_destroy :check_if_deletable

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
    Rails.cache.fetch("user_#{id}_active_tickets", expires_in: 1.hour) do
      tickets.where("remaining_count > 0").sum(:remaining_count)
    end
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

  def clear_ticket_cache
    Rails.cache.delete("user_#{id}_active_tickets")
  end

  private

  def check_if_deletable
    # 特別な条件があれば削除を阻止
    # 例：管理者ユーザーの削除を防ぐ
    if admin?
      errors.add(:base, "管理者ユーザーは削除できません")
      throw(:abort)
    end
    
    # 例：アクティブなチケットがある場合の警告（削除は可能）
    if active_ticket_count > 0
      Rails.logger.warn "⚠️ Deleting user with active tickets: #{name} (#{active_ticket_count} tickets)"
    end
  end
end
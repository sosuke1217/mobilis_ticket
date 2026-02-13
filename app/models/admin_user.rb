class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :lockable, :timeoutable
  
  # パスワードの複雑性要件
  validate :password_complexity
  
  private
  
  def password_complexity
    return if password.blank? || password.nil?
    
    errors.add(:password, 'は8文字以上である必要があります') if password.length < 8
    errors.add(:password, 'は大文字と小文字を含む必要があります') unless password.match?(/[a-z]/) && password.match?(/[A-Z]/)
    errors.add(:password, 'は数字を含む必要があります') unless password.match?(/\d/)
    errors.add(:password, 'は記号を含む必要があります') unless password.match?(/[^a-zA-Z0-9]/)
  end
end

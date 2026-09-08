class AdminUser < ApplicationRecord
  BACKUP_CODE_COUNT = 8
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :lockable, :timeoutable

  def otp_secret
    return if otp_secret_ciphertext.blank?

    self.class.otp_encryptor.decrypt_and_verify(otp_secret_ciphertext)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def otp_secret=(secret)
    self.otp_secret_ciphertext = secret.present? ? self.class.otp_encryptor.encrypt_and_sign(secret) : nil
  end

  def verify_otp(code)
    TotpService.valid?(otp_secret, code)
  end

  def generate_backup_codes
    codes = Array.new(BACKUP_CODE_COUNT) { SecureRandom.hex(5).upcase }
    self.otp_backup_code_digests = codes.map { |code| Digest::SHA256.hexdigest(code) }
    codes
  end

  def consume_backup_code(code)
    digest = Digest::SHA256.hexdigest(code.to_s.delete(" -").upcase)
    matching = otp_backup_code_digests.find do |stored|
      ActiveSupport::SecurityUtils.secure_compare(stored, digest)
    end
    return false unless matching

    self.otp_backup_code_digests = otp_backup_code_digests - [matching]
    save!
    true
  end

  def self.otp_encryptor
    key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)
      .generate_key("mobilis-admin-otp", ActiveSupport::MessageEncryptor.key_len)
    ActiveSupport::MessageEncryptor.new(key)
  end
  
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

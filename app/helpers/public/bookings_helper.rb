module Public::BookingsHelper
  def masked_email(email)
    local, domain = email.to_s.split('@', 2)
    return '未登録 / Not available' if local.blank? || domain.blank?

    "#{local.first}***@#{domain}"
  end
end

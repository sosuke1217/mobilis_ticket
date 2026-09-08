class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('MAIL_FROM', 'noreply@mobilis-stretch.com')
  layout "mailer"
  
  private
  
  def mail_enabled?
    Rails.env.production? || Rails.env.development?
  end
  
  # エラーハンドリング付きメール送信
  def safe_deliver(mail)
    return unless mail_enabled?
    
    begin
      mail.deliver_now
      Rails.logger.info "📧 [MAIL] Successfully sent: message_id=#{mail.message_id}"
    rescue Net::SMTPError => e
      Rails.logger.error "📧 [MAIL ERROR] SMTP Error: #{e.message}"
      raise e if Rails.env.development?
    rescue => e
      Rails.logger.error "📧 [MAIL ERROR] Unexpected error: #{e.message}"
      raise e if Rails.env.development?
    end
  end
end

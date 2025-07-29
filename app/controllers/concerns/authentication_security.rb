module AuthenticationSecurity
  extend ActiveSupport::Concern
  
  included do
    before_action :track_authentication_attempts, only: [:create] # ログインアクション
  end
  
  private
  
  def track_authentication_attempts
    return unless params[:admin_user] || params[:user] # ログイン試行時のみ
    
    ip_key = "login_attempts:#{request.remote_ip}"
    current_attempts = Rails.cache.read(ip_key) || 0
    
    # 失敗回数をカウント
    Rails.cache.write(ip_key, current_attempts + 1, expires_in: 10.minutes)
    
    # 5回以上失敗した場合
    if current_attempts >= 5
      SecurityMonitor.log_suspicious_activity(
        :multiple_failed_logins,
        {
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          attempt_count: current_attempts + 1,
          email: params.dig(:admin_user, :email) || params.dig(:user, :email)
        }
      )
      
      # 一定時間ブロック
      render json: { error: "Too many login attempts. Please try again later." }, 
             status: :too_many_requests
      return
    end
  end
  
  def reset_authentication_attempts
    ip_key = "login_attempts:#{request.remote_ip}"
    Rails.cache.delete(ip_key)
  end
end

module RateLimiting
  extend ActiveSupport::Concern
  
  included do
    before_action :check_rate_limit, only: [:create, :update, :destroy]
  end
  
  private
  
  def check_rate_limit
    identifier = rate_limit_identifier
    key = "rate_limit:#{identifier}:#{action_name}"
    
    current_count = Rails.cache.read(key) || 0
    limit = rate_limit_for_action
    
    if current_count >= limit
      handle_rate_limit_exceeded
      return
    end
    
    Rails.cache.write(key, current_count + 1, expires_in: 1.minute)
  end
  
  def rate_limit_identifier
    if user_signed_in?
      "user:#{current_user.id}"
    elsif admin_user_signed_in?
      "admin:#{current_admin_user.id}"
    else
      "ip:#{request.remote_ip}"
    end
  end
  
  def rate_limit_for_action
    case action_name
    when 'create'
      user_signed_in? ? 30 : 10  # ログインユーザーは30回/分、ゲストは10回/分
    when 'update', 'destroy'
      user_signed_in? ? 20 : 5
    else
      50
    end
  end
  
  def handle_rate_limit_exceeded
    respond_to do |format|
      format.html do
        flash[:alert] = "リクエストが多すぎます。しばらく時間をおいてから再度お試しください。"
        redirect_back(fallback_location: root_path)
      end
      format.json do
        render json: { 
          success: false, 
          error: "Rate limit exceeded. Please try again later.",
          retry_after: 60
        }, status: :too_many_requests
      end
    end
  end
end
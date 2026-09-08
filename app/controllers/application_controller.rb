class ApplicationController < ActionController::Base
  before_action :require_admin_two_factor!
  # セキュリティヘッダーの設定
  include SecurityHeaders
  
  # エラーハンドリングの統一
  include ErrorHandling

  def after_sign_in_path_for(resource)
    if resource.is_a?(AdminUser)
      resource.otp_required_for_login? && !session[:admin_two_factor_verified] ? admin_user_two_factor_path : admin_root_path
    else
      super
    end
  end

  private

  def require_admin_two_factor!
    return unless admin_user_signed_in?
    return unless current_admin_user.otp_required_for_login?
    return if session[:admin_two_factor_verified]
    return if controller_path == "admin_users/two_factor"
    return if controller_path == "admin_users/sessions" && action_name == "destroy"

    redirect_to admin_user_two_factor_path
  end
end

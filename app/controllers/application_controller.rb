class ApplicationController < ActionController::Base
  # セキュリティヘッダーの設定
  include SecurityHeaders
  
  # エラーハンドリングの統一
  include ErrorHandling

  def after_sign_in_path_for(resource)
    if resource.is_a?(AdminUser)
      admin_root_path
    else
      super
    end
  end
end
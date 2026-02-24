class ApplicationController < ActionController::Base
  # セキュリティヘッダーの設定
  include SecurityHeaders
  
  # エラーハンドリングの統一
  include ErrorHandling

  # リダイレクトを常に「今のリクエストのホスト」に合わせてループを防ぐ
  def default_url_options
    return {} unless request
    protocol = Rails.env.production? ? "https" : request.protocol
    opts = { host: request.host, protocol: protocol }
    opts[:port] = request.port if request.port.present? && ![80, 443].include?(request.port)
    opts
  end

  def after_sign_in_path_for(resource)
    if resource.is_a?(AdminUser)
      admin_root_path
    else
      super
    end
  end
end
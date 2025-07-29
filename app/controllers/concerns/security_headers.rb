module SecurityHeaders
  extend ActiveSupport::Concern
  
  included do
    before_action :set_security_headers
  end
  
  private
  
  def set_security_headers
    # CSRF対策
    response.headers['X-Frame-Options'] = 'SAMEORIGIN'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    
    # HTTPS強制（本番環境のみ）
    if Rails.env.production?
      response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    end
    
    # CSP（Content Security Policy）
    csp_directives = [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdnjs.cloudflare.com https://cdn.jsdelivr.net https://unpkg.com",
      "style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com https://cdn.jsdelivr.net",
      "img-src 'self' data: https:",
      "font-src 'self' https://cdnjs.cloudflare.com",
      "connect-src 'self' https://api.line.me",
      "frame-ancestors 'none'"
    ]
    
    response.headers['Content-Security-Policy'] = csp_directives.join('; ')
  end
end

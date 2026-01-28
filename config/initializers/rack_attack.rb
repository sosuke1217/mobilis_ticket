# Be sure to restart your server when you modify this file.

# Rack::Attackの設定
# 注意: rack-attack gemがインストールされている必要があります
begin
  require 'rack/attack'
  
  class Rack::Attack
  # 開発環境とテスト環境では無効化
  unless Rails.env.development? || Rails.env.test?
    # リクエストのスロットリング（IPアドレス単位）
    throttle('req/ip', limit: 300, period: 5.minutes) do |req|
      req.ip unless req.path.start_with?('/assets', '/packs')
    end

    # ログイン試行のスロットリング（IPアドレス単位）
    throttle('logins/ip', limit: 5, period: 20.minutes) do |req|
      if req.path == '/admin_users/sign_in' && req.post?
        req.ip
      end
    end

    # ログイン試行のスロットリング（メールアドレス単位）
    throttle('logins/email', limit: 5, period: 20.minutes) do |req|
      if req.path == '/admin_users/sign_in' && req.post?
        req.params['admin_user']['email'].to_s.downcase.gsub(/\s+/, "") rescue nil
      end
    end

    # 一般ユーザーのログイン試行
    throttle('user_logins/ip', limit: 5, period: 20.minutes) do |req|
      if req.path == '/users/sign_in' && req.post?
        req.ip
      end
    end

    throttle('user_logins/email', limit: 5, period: 20.minutes) do |req|
      if req.path == '/users/sign_in' && req.post?
        req.params['user']['email'].to_s.downcase.gsub(/\s+/, "") rescue nil
      end
    end

    # LINE Botコールバックのスロットリング
    throttle('linebot/callback', limit: 100, period: 1.minute) do |req|
      if req.path == '/linebot/callback' && req.post?
        req.ip
      end
    end

    # ユーザー作成のスロットリング
    throttle('users/create', limit: 10, period: 1.hour) do |req|
      if req.path.include?('/users') && req.post? && !req.path.include?('/sign_in')
        req.ip
      end
    end

    # 予約作成のスロットリング
    throttle('reservations/create', limit: 20, period: 1.hour) do |req|
      if req.path.include?('/reservations') && req.post?
        req.ip
      end
    end

    # 管理者操作のスロットリング
    throttle('admin/actions', limit: 100, period: 1.minute) do |req|
      if req.path.start_with?('/admin/') && req.post? || req.patch? || req.put? || req.delete?
        req.ip
      end
    end
  end

  # ブロックされたリクエストの処理
  self.blocked_response = lambda do |env|
    [
      429, # status
      { 'Content-Type' => 'application/json' }, # headers
      [{ error: 'Rate limit exceeded. Please try again later.' }.to_json] # body
    ]
  end

  # ログ記録
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, req|
    case req.env['rack.attack.match_type']
    when :throttle
      Rails.logger.warn "[Rack::Attack] Throttled #{req.env['rack.attack.match_type']} #{req.ip} #{req.path}"
    when :blocklist
      Rails.logger.error "[Rack::Attack] Blocked #{req.env['rack.attack.match_type']} #{req.ip} #{req.path}"
    end
  end
  
  # Rack::Attackミドルウェアを有効化
  Rails.application.config.middleware.use Rack::Attack
rescue LoadError
  Rails.logger.warn "rack-attack gem is not installed. Rate limiting is disabled."
end


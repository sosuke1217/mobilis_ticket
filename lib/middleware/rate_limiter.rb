require "digest"

# Simple, dependency-free rate limiter middleware.
# Uses Rails.cache (memory store by default on Heroku single dyno) to count requests.
#
# Strategy:
# - Match request paths/methods to "buckets"
# - Limit requests per IP within a time window
# - Return 429 on limit exceeded
#
# Note: This is best-effort on multi-dyno unless cache is shared (e.g., Redis).
class RateLimiter
  DEFAULT_RULES = [
    # Admin login attempts
    { name: "admin_login",  methods: ["POST"], paths: ["/admin_users/sign_in"], limit: 5, period: 15 * 60 },
    # User login attempts
    { name: "user_login",   methods: ["POST"], paths: ["/users/sign_in"],       limit: 20, period: 20 * 60 },
    # LINE bot callback
    { name: "line_callback", methods: ["POST"], paths: ["/linebot/callback"],    limit: 300, period: 60 },
    # Reservation creation endpoints (public + admin)
    { name: "public_booking_create", methods: ["POST"], paths: ["/public/bookings"], limit: 5, period: 10 * 60 },
    { name: "reservation_create", methods: ["POST"], paths: ["/reservations", "/admin/reservations"], limit: 120, period: 60 },
    # Generic admin write actions
    { name: "admin_write", methods: ["POST", "PATCH", "PUT", "DELETE"], path_prefixes: ["/admin/"], limit: 600, period: 60 }
  ].freeze

  def initialize(app, rules: DEFAULT_RULES)
    @app = app
    @rules = rules
  end

  def self.reset!(rule_name, ip)
    Rails.cache.delete(cache_key_for(rule_name, ip))
  end

  def self.cache_key_for(rule_name, ip)
    digest = Digest::SHA256.hexdigest("#{rule_name}:#{ip}")
    "rate_limit:#{rule_name}:#{digest}"
  end

  def call(env)
    req = Rack::Request.new(env)

    rule = match_rule(req)
    return @app.call(env) unless rule

    ip = req.ip.to_s
    return @app.call(env) if ip.empty?

    key = cache_key(rule[:name], ip)
    count = increment_with_expiry(key, rule[:period])

    if count > rule[:limit]
      return rate_limited_response(req, rule, count)
    end

    @app.call(env)
  end

  private

  def match_rule(req)
    method = req.request_method
    path = req.path

    @rules.find do |r|
      next false if r[:methods] && !r[:methods].include?(method)

      exact = r[:paths]&.include?(path)
      prefix = r[:path_prefixes]&.any? { |p| path.start_with?(p) }
      exact || prefix
    end
  end

  def cache_key(rule_name, ip)
    self.class.cache_key_for(rule_name, ip)
  end

  def increment_with_expiry(key, period)
    cache = Rails.cache
    # Rails cache increment only works for some stores; fallback to read/write.
    if cache.respond_to?(:increment)
      current = cache.increment(key, 1, expires_in: period)
      return current if current
    end

    current = (cache.read(key) || 0).to_i + 1
    cache.write(key, current, expires_in: period)
    current
  end

  def rate_limited_response(req, rule, count)
    ip_hash = Digest::SHA256.hexdigest(req.ip.to_s).first(12)
    Rails.logger.warn("[RateLimiter] 429 #{rule[:name]} ip_hash=#{ip_hash} path=#{req.path} count=#{count} limit=#{rule[:limit]}")

    if req.get_header("HTTP_ACCEPT").to_s.include?("text/html")
      body = <<~HTML
        <!doctype html>
        <html lang="ja">
          <head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Too Many Requests</title></head>
          <body style="font-family:sans-serif;max-width:680px;margin:64px auto;padding:0 24px;line-height:1.7">
            <h1>しばらく時間をおいてください</h1>
            <p>短時間に複数回の送信がありました。10分ほど待ってから、もう一度お試しください。</p>
            <p>Too many booking attempts were submitted. Please wait about 10 minutes and try again.</p>
            <p><a href="/public/bookings/new">予約画面へ戻る / Back to booking</a></p>
          </body>
        </html>
      HTML
      content_type = "text/html; charset=utf-8"
    else
      body = { error: "rate_limited", message: "リクエストが多すぎます。しばらくしてから再度お試しください。" }.to_json
      content_type = "application/json; charset=utf-8"
    end

    [
      429,
      {
        "Content-Type" => content_type,
        "Retry-After" => rule[:period].to_s
      },
      [body]
    ]
  end
end

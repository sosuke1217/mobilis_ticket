class SecurityMonitor
  include Singleton
  
  def self.log_suspicious_activity(activity_type, details = {})
    instance.log_suspicious_activity(activity_type, details)
  end
  
  def self.check_for_threats
    instance.check_for_threats
  end
  
  def log_suspicious_activity(activity_type, details = {})
    security_log = {
      timestamp: Time.current.iso8601,
      activity_type: activity_type,
      details: details,
      severity: determine_severity(activity_type)
    }
    
    Rails.logger.warn "🔒 [SECURITY] #{activity_type}: #{details.inspect}"
    
    # ファイルログに記録
    log_to_security_file(security_log)
    
    # 重要度が高い場合は即座に通知
    if security_log[:severity] == :high
      ErrorHandlingService.notify_admin("セキュリティアラート: #{activity_type}", :critical)
    end
  end
  
  def check_for_threats
    threats = []
    
    # 1. 異常なログイン試行をチェック
    threats.concat(check_login_attempts)
    
    # 2. 大量リクエストをチェック
    threats.concat(check_excessive_requests)
    
    # 3. 異常なユーザー作成をチェック
    threats.concat(check_user_creation_patterns)
    
    # 4. LINE API の異常使用をチェック
    threats.concat(check_line_api_abuse)
    
    threats.each do |threat|
      log_suspicious_activity(threat[:type], threat[:details])
    end
    
    threats
  end
  
  private
  
  def determine_severity(activity_type)
    high_severity_activities = [
      :multiple_failed_logins,
      :sql_injection_attempt,
      :xss_attempt,
      :unusual_admin_access,
      :bulk_user_creation
    ]
    
    medium_severity_activities = [
      :suspicious_user_agent,
      :unusual_location,
      :rate_limit_exceeded,
      :invalid_csrf_token
    ]
    
    if high_severity_activities.include?(activity_type.to_sym)
      :high
    elsif medium_severity_activities.include?(activity_type.to_sym)
      :medium
    else
      :low
    end
  end
  
  def log_to_security_file(security_log)
    log_dir = Rails.root.join('log', 'security')
    FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
    
    date_str = Time.current.strftime('%Y%m%d')
    log_file = log_dir.join("security_#{date_str}.log")
    
    File.open(log_file, 'a') do |file|
      file.puts JSON.generate(security_log)
    end
  end
  
  def check_login_attempts
    threats = []
    
    # 過去10分間で同一IPから5回以上のログイン失敗
    failed_attempts = Rails.cache.read_multi(*generate_ip_keys)
    
    failed_attempts.each do |key, count|
      if count && count >= 5
        ip = key.split(':').last
        threats << {
          type: :multiple_failed_logins,
          details: { ip_address: ip, attempt_count: count }
        }
      end
    end
    
    threats
  end
  
  def check_excessive_requests
    threats = []
    
    # 実装例：過去1分間で100回以上のリクエスト
    # ログファイルから検出するか、Redis/Memcachedでカウント
    
    threats
  end
  
  def check_user_creation_patterns
    threats = []
    
    # 過去1時間で10人以上のユーザー作成
    recent_users = User.where('created_at > ?', 1.hour.ago).count
    
    if recent_users >= 10
      threats << {
        type: :bulk_user_creation,
        details: { user_count: recent_users, timeframe: '1 hour' }
      }
    end
    
    threats
  end
  
  def check_line_api_abuse
    threats = []
    
    # LINE API の異常な使用パターンをチェック
    # 例：短時間での大量メッセージ送信
    
    threats
  end
  
  def generate_ip_keys
    # 最近のIPアドレスのキーを生成（実装例）
    []
  end
end

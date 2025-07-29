# app/services/error_handling_service.rb

class ErrorHandlingService
  include Singleton
  
  def self.log_error(error, context = {})
    instance.log_error(error, context)
  end
  
  def self.notify_admin(message, level = :warning)
    instance.notify_admin(message, level)
  end
  
  def log_error(error, context = {})
    error_data = {
      timestamp: Time.current.iso8601,
      error_class: error.class.name,
      error_message: error.message,
      backtrace: error.backtrace&.first(10),
      context: context,
      request_id: context[:request_id],
      user_id: context[:user_id],
      action: context[:action]
    }
    
    # Railsログに出力
    Rails.logger.error "🔥 [ERROR] #{error.class.name}: #{error.message}"
    Rails.logger.error "📍 Context: #{context.inspect}"
    Rails.logger.error "📚 Backtrace:\n#{error.backtrace&.first(5)&.join("\n")}"
    
    # ファイルログに詳細を保存
    log_to_file(error_data)
    
    # 重要なエラーの場合は管理者に通知
    if critical_error?(error)
      notify_admin("重要なエラーが発生しました: #{error.class.name}", :critical)
    end
  end
  
  def notify_admin(message, level = :warning)
    # Slackやメール通知（実装例）
    case level
    when :critical
      send_critical_notification(message)
    when :warning
      send_warning_notification(message)
    else
      Rails.logger.warn "📢 [ADMIN NOTIFY] #{message}"
    end
  end
  
  private
  
  def log_to_file(error_data)
    log_dir = Rails.root.join('log', 'errors')
    FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
    
    date_str = Time.current.strftime('%Y%m%d')
    log_file = log_dir.join("errors_#{date_str}.log")
    
    File.open(log_file, 'a') do |file|
      file.puts "=" * 80
      file.puts "Timestamp: #{error_data[:timestamp]}"
      file.puts "Error: #{error_data[:error_class]} - #{error_data[:error_message]}"
      file.puts "Context: #{error_data[:context].inspect}"
      file.puts "Backtrace:"
      error_data[:backtrace]&.each { |line| file.puts "  #{line}" }
      file.puts "=" * 80
      file.puts
    end
  end
  
  def critical_error?(error)
    critical_classes = [
      ActiveRecord::StatementInvalid,
      NoMethodError,
      SystemExit,
      SecurityError
    ]
    
    critical_classes.any? { |klass| error.is_a?(klass) }
  end
  
  def send_critical_notification(message)
    # Slack通知の実装例
    if ENV['SLACK_WEBHOOK_URL']
      send_slack_notification(message, :critical)
    end
    
    # メール通知
    if ENV['ADMIN_EMAIL']
      AdminMailer.critical_error_notification(message).deliver_now rescue nil
    end
    
    Rails.logger.error "🚨 [CRITICAL] #{message}"
  end
  
  def send_warning_notification(message)
    Rails.logger.warn "⚠️ [WARNING] #{message}"
  end
  
  def send_slack_notification(message, level)
    return unless ENV['SLACK_WEBHOOK_URL']
    
    color = level == :critical ? '#ff0000' : '#ffaa00'
    emoji = level == :critical ? '🚨' : '⚠️'
    
    payload = {
      text: "#{emoji} Mobilis システム通知",
      attachments: [
        {
          color: color,
          fields: [
            {
              title: "レベル",
              value: level.to_s.upcase,
              short: true
            },
            {
              title: "メッセージ",
              value: message,
              short: false
            },
            {
              title: "時刻",
              value: Time.current.strftime('%Y-%m-%d %H:%M:%S'),
              short: true
            }
          ]
        }
      ]
    }
    
    uri = URI(ENV['SLACK_WEBHOOK_URL'])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new
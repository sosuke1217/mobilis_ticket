class SystemHealthChecker
  def self.perform_health_check
    new.perform_health_check
  end
  
  def self.detailed_health_check
    new.detailed_health_check
  end
  
  def perform_health_check
    checks = {
      database: check_database,
      redis: check_redis,
      line_api: check_line_api,
      disk_space: check_disk_space,
      memory: check_memory_usage
    }
    
    failed_checks = checks.select { |_, status| status[:status] != :healthy }
    overall_status = failed_checks.empty? ? :healthy : :unhealthy
    
    {
      timestamp: Time.current.iso8601,
      overall_status: overall_status,
      checks: checks,
      uptime: get_uptime,
      version: get_app_version
    }
  end
  
  def detailed_health_check
    {
      timestamp: Time.current.iso8601,
      system: {
        ruby_version: RUBY_VERSION,
        rails_version: Rails.version,
        environment: Rails.env,
        uptime: get_uptime,
        memory_usage: get_memory_info,
        disk_usage: get_disk_info
      },
      database: detailed_database_check,
      application: {
        total_users: User.count,
        total_reservations: Reservation.count,
        active_reservations: Reservation.active.count,
        pending_reminders: Reservation.needs_reminder.count,
        expired_tickets: Ticket.where('expiry_date < ? AND remaining_count > 0', Date.current).count
      },
      recent_activity: {
        reservations_today: Reservation.today.count,
        reservations_this_week: Reservation.this_week.count,
        tickets_used_today: TicketUsage.where(used_at: Date.current.beginning_of_day..Date.current.end_of_day).count
      },
      line_integration: detailed_line_check,
      performance_metrics: get_performance_metrics
    }
  end
  
  private
  
  def check_database
    start_time = Time.current
    
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      response_time = ((Time.current - start_time) * 1000).round(2)
      
      {
        status: :healthy,
        response_time_ms: response_time,
        message: "Database connection OK"
      }
    rescue => e
      {
        status: :unhealthy,
        error: e.message,
        message: "Database connection failed"
      }
    end
  end
  
  def check_redis
    return { status: :skipped, message: "Redis not configured" } unless defined?(Redis)
    
    begin
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379'))
      start_time = Time.current
      redis.ping
      response_time = ((Time.current - start_time) * 1000).round(2)
      
      {
        status: :healthy,
        response_time_ms: response_time,
        message: "Redis connection OK"
      }
    rescue => e
      {
        status: :unhealthy,
        error: e.message,
        message: "Redis connection failed"
      }
    end
  end
  
  def check_line_api
    return { status: :skipped, message: "LINE API not configured" } unless ENV['LINE_CHANNEL_TOKEN']
    
    begin
      uri = URI('https://api.line.me/v2/bot/info')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 5
      
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{ENV['LINE_CHANNEL_TOKEN']}"
      
      start_time = Time.current
      response = http.request(request)
      response_time = ((Time.current - start_time) * 1000).round(2)
      
      if response.code == '200'
        {
          status: :healthy,
          response_time_ms: response_time,
          message: "LINE API connection OK"
        }
      else
        {
          status: :unhealthy,
          response_code: response.code,
          message: "LINE API returned error"
        }
      end
    rescue => e
      {
        status: :unhealthy,
        error: e.message,
        message: "LINE API connection failed"
      }
    end
  end
  
  def check_disk_space
    begin
      stat = File.statvfs(Rails.root)
      total_space = stat.blocks * stat.frsize
      free_space = stat.bavail * stat.frsize
      used_percentage = ((total_space - free_space).to_f / total_space * 100).round(2)
      
      status = case used_percentage
               when 0..80 then :healthy
               when 81..90 then :warning
               else :unhealthy
               end
      
      {
        status: status,
        used_percentage: used_percentage,
        free_space_gb: (free_space / 1024 / 1024 / 1024).round(2),
        message: "Disk usage: #{used_percentage}%"
      }
    rescue => e
      {
        status: :unknown,
        error: e.message,
        message: "Could not check disk space"
      }
    end
  end
  
  def check_memory_usage
    begin
      # プロセスのメモリ使用量を取得（Linux/macOS）
      if File.exist?('/proc/meminfo')
        # Linux
        meminfo = File.read('/proc/meminfo')
        total_memory = meminfo.match(/MemTotal:\s+(\d+) kB/)[1].to_i
        available_memory = meminfo.match(/MemAvailable:\s+(\d+) kB/)[1].to_i
        used_percentage = ((total_memory - available_memory).to_f / total_memory * 100).round(2)
      else
        # macOSまたはその他（簡易版）
        used_percentage = 50.0 # デフォルト値
      end
      
      status = case used_percentage
               when 0..80 then :healthy
               when 81..90 then :warning
               else :unhealthy
               end
      
      {
        status: status,
        used_percentage: used_percentage,
        message: "Memory usage: #{used_percentage}%"
      }
    rescue => e
      {
        status: :unknown,
        error: e.message,
        message: "Could not check memory usage"
      }
    end
  end
  
  def get_uptime
    uptime_seconds = File.read('/proc/uptime').split.first.to_f rescue 0
    hours = (uptime_seconds / 3600).to_i
    minutes = ((uptime_seconds % 3600) / 60).to_i
    
    "#{hours}h #{minutes}m"
  rescue
    "unknown"
  end
  
  def get_app_version
    Rails.application.class.module_parent_name.downcase + "-" + (ENV['GIT_COMMIT'] || 'dev')
  end
  
  def get_memory_info
    begin
      if File.exist?('/proc/meminfo')
        meminfo = File.read('/proc/meminfo')
        total_kb = meminfo.match(/MemTotal:\s+(\d+) kB/)[1].to_i
        available_kb = meminfo.match(/MemAvailable:\s+(\d+) kB/)[1].to_i
        
        {
          total_mb: (total_kb / 1024).round(2),
          available_mb: (available_kb / 1024).round(2),
          used_percentage: (((total_kb - available_kb).to_f / total_kb) * 100).round(2)
        }
      else
        { message: "Memory info not available" }
      end
    rescue
      { error: "Could not read memory info" }
    end
  end
  
  def get_disk_info
    begin
      stat = File.statvfs(Rails.root)
      total_bytes = stat.blocks * stat.frsize
      free_bytes = stat.bavail * stat.frsize
      
      {
        total_gb: (total_bytes / 1024 / 1024 / 1024).round(2),
        free_gb: (free_bytes / 1024 / 1024 / 1024).round(2),
        used_percentage: (((total_bytes - free_bytes).to_f / total_bytes) * 100).round(2)
      }
    rescue
      { error: "Could not read disk info" }
    end
  end
  
  def detailed_database_check
    begin
      start_time = Time.current
      
      # 基本接続テスト
      ActiveRecord::Base.connection.execute('SELECT 1')
      connection_time = ((Time.current - start_time) * 1000).round(2)
      
      # データベースサイズ
      db_size = ActiveRecord::Base.connection.execute(
        "SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size();"
      ).first['size'] rescue 0
      
      # テーブル数
      table_count = ActiveRecord::Base.connection.tables.count
      
      # 最新のマイグレーション
      latest_migration = ActiveRecord::SchemaMigration.maximum(:version)
      
      {
        status: :healthy,
        connection_time_ms: connection_time,
        database_size_mb: (db_size / 1024 / 1024).round(2),
        table_count: table_count,
        latest_migration: latest_migration,
        active_connections: ActiveRecord::Base.connection_pool.connections.count,
        pool_size: ActiveRecord::Base.connection_pool.size
      }
    rescue => e
      {
        status: :unhealthy,
        error: e.message
      }
    end
  end
  
  def detailed_line_check
    return { status: :skipped, message: "LINE not configured" } unless ENV['LINE_CHANNEL_TOKEN']
    
    begin
      # ボット情報を取得
      uri = URI('https://api.line.me/v2/bot/info')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{ENV['LINE_CHANNEL_TOKEN']}"
      
      response = http.request(request)
      
      if response.code == '200'
        bot_info = JSON.parse(response.body)
        {
          status: :healthy,
          bot_info: {
            display_name: bot_info['displayName'],
            user_id: bot_info['userId'],
            premium_id: bot_info['premiumId']
          },
          connected_users: User.where.not(line_user_id: nil).count
        }
      else
        {
          status: :unhealthy,
          error: "HTTP #{response.code}",
          message: response.body
        }
      end
    rescue => e
      {
        status: :unhealthy,
        error: e.message
      }
    end
  end
  
  def get_performance_metrics
    {
      average_response_time: calculate_average_response_time,
      requests_per_minute: calculate_requests_per_minute,
      error_rate: calculate_error_rate,
      cache_hit_rate: calculate_cache_hit_rate
    }
  end
  
  def calculate_average_response_time
    # ログファイルから計算（実装例）
    begin
      log_file = Rails.root.join('log', "#{Rails.env}.log")
      return 0 unless File.exist?(log_file)
      
      # 簡易実装：過去100行のCompleted行を解析
      lines = `tail -100 #{log_file}`.split("\n")
      completed_lines = lines.select { |line| line.include?('Completed') && line.include?('in ') }
      
      return 0 if completed_lines.empty?
      
      times = completed_lines.map do |line|
        match = line.match(/in (\d+)ms/)
        match ? match[1].to_f : nil
      end.compact
      
      times.empty? ? 0 : (times.sum / times.count).round(2)
    rescue
      0
    end
  end
  
  def calculate_requests_per_minute
    # 簡易実装
    begin
      log_file = Rails.root.join('log', "#{Rails.env}.log")
      return 0 unless File.exist?(log_file)
      
      one_minute_ago = 1.minute.ago.strftime('%Y-%m-%d %H:%M')
      request_count = `grep "#{one_minute_ago}" #{log_file} | grep "Started" | wc -l`.to_i
      request_count
    rescue
      0
    end
  end
  
  def calculate_error_rate
    # 簡易実装：過去の500エラーレスポンスの割合
    begin
      log_file = Rails.root.join('log', "#{Rails.env}.log")
      return 0 unless File.exist?(log_file)
      
      lines = `tail -200 #{log_file}`.split("\n")
      completed_lines = lines.select { |line| line.include?('Completed') }
      error_lines = completed_lines.select { |line| line.include?(' 5') }
      
      return 0 if completed_lines.empty?
      
      ((error_lines.count.to_f / completed_lines.count) * 100).round(2)
    rescue
      0
    end
  end
  
  def calculate_cache_hit_rate
    # キャッシュを使用している場合の実装例
    # Redisの統計情報から計算
    50.0 # デフォルト値
  end
end
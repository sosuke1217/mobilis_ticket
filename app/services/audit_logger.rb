class AuditLogger
  def self.log_action(action:, model:, record_id:, changes:, user: nil)
    log_entry = {
      timestamp: Time.current.iso8601,
      action: action,
      model: model,
      record_id: record_id,
      changes: changes,
      user: user ? {
        id: user.id,
        type: user.class.name,
        identifier: user.respond_to?(:email) ? user.email : user.name
      } : nil,
      ip_address: Thread.current[:request_ip],
      user_agent: Thread.current[:request_user_agent]
    }
    
    # ファイルログに記録
    log_to_audit_file(log_entry)
    
    # 重要なアクションの場合はリアルタイム通知
    if critical_action?(action, model)
      ErrorHandlingService.notify_admin(
        "重要なデータ変更: #{model}##{action} (ID: #{record_id})",
        :warning
      )
    end
  end
  
  private
  
  def self.log_to_audit_file(log_entry)
    log_dir = Rails.root.join('log', 'audit')
    FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
    
    date_str = Time.current.strftime('%Y%m%d')
    log_file = log_dir.join("audit_#{date_str}.log")
    
    File.open(log_file, 'a') do |file|
      file.puts JSON.generate(log_entry)
    end
  end
  
  def self.critical_action?(action, model)
    critical_models = ['AdminUser', 'User', 'Ticket', 'TicketTemplate']
    critical_actions = ['destroy']
    
    critical_models.include?(model) && critical_actions.include?(action)
  end
end
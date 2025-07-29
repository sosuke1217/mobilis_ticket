module AuditLogging
  extend ActiveSupport::Concern
  
  included do
    after_create :log_create_action
    after_update :log_update_action
    after_destroy :log_destroy_action
  end
  
  private
  
  def log_create_action
    AuditLogger.log_action(
      action: 'create',
      model: self.class.name,
      record_id: id,
      changes: attributes,
      user: current_audit_user
    )
  end
  
  def log_update_action
    return unless saved_changes.any?
    
    AuditLogger.log_action(
      action: 'update',
      model: self.class.name,
      record_id: id,
      changes: saved_changes,
      user: current_audit_user
    )
  end
  
  def log_destroy_action
    AuditLogger.log_action(
      action: 'destroy',
      model: self.class.name,
      record_id: id,
      changes: attributes,
      user: current_audit_user
    )
  end
  
  def current_audit_user
    # RequestStoreやCurrentAttributesを使用してユーザー情報を取得
    Thread.current[:current_user] || Thread.current[:current_admin_user]
  end
end

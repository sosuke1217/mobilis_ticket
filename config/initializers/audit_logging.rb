Rails.application.configure do
  config.to_prepare do
    # 監査ログが必要なモデルにAuditLoggingを追加
    [User, AdminUser, Ticket, TicketTemplate, Reservation].each do |model|
      model.include AuditLogging
    end
  end
end
# config/initializers/google_calendar_credentials.rb
# Googleカレンダー認証情報ファイルを環境変数から動的に生成

if Rails.env.production? && ENV['GOOGLE_CALENDAR_SYNC_ENABLED'] == 'true'
  credentials_path = Rails.root.join('config', 'google_calendar_credentials.json')
  
  # 環境変数から認証情報を取得
  client_id = ENV['GOOGLE_CALENDAR_CLIENT_ID']
  client_secret = ENV['GOOGLE_CALENDAR_CLIENT_SECRET']
  project_id = ENV['GOOGLE_CALENDAR_PROJECT_ID'] || 'mobilis-ticket'
  
  # 環境変数が設定されている場合、認証情報ファイルを生成
  if client_id.present? && client_secret.present?
    unless File.exist?(credentials_path)
      credentials_data = {
        installed: {
          client_id: client_id,
          project_id: project_id,
          auth_uri: "https://accounts.google.com/o/oauth2/auth",
          token_uri: "https://oauth2.googleapis.com/token",
          auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
          client_secret: client_secret,
          redirect_uris: ["http://localhost"]
        }
      }
      
      File.write(credentials_path, JSON.pretty_generate(credentials_data))
      Rails.logger.info "✅ Google Calendar credentials file created from environment variables"
    end
  else
    Rails.logger.warn "⚠️ Google Calendar credentials environment variables not set"
  end
end


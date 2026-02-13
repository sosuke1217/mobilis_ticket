# lib/google_auth_stores/database_token_store.rb
# Google OAuthトークンをデータベースに保存するカスタムストア

require 'googleauth/stores/token_store'

module GoogleAuthStores
  class DatabaseTokenStore
    include Google::Auth::Stores::TokenStore

    def load(id)
      token_record = GoogleCalendarToken.find_by(user_id: id)
      return nil unless token_record
      
      token_record.token_hash
    rescue => e
      Rails.logger.error "❌ Failed to load token from database: #{e.message}"
      nil
    end

    def store(id, token)
      token_record = GoogleCalendarToken.find_or_initialize_by(user_id: id)
      token_record.token_hash = token
      token_record.save!
      Rails.logger.info "✅ Token stored in database for user_id: #{id}"
    rescue => e
      Rails.logger.error "❌ Failed to store token in database: #{e.message}"
      raise
    end

    def delete(id)
      token_record = GoogleCalendarToken.find_by(user_id: id)
      token_record&.destroy!
      Rails.logger.info "✅ Token deleted from database for user_id: #{id}"
    rescue => e
      Rails.logger.error "❌ Failed to delete token from database: #{e.message}"
      raise
    end
  end
end


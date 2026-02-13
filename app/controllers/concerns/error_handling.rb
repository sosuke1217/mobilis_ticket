module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  end

  private

  def handle_standard_error(error)
    # エラーの詳細をログに記録（本番環境では簡潔に）
    if Rails.env.production?
      Rails.logger.error "#{error.class.name}: #{error.message}"
      Rails.logger.error error.backtrace.first(5).join("\n")
    else
      Rails.logger.error "#{error.class.name}: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")
    end

    respond_to do |format|
      format.html { 
        # Public::BookingsControllerの場合は詳細なエラーメッセージを表示（ただし機密情報は除外）
        if self.class.name.start_with?('Public::')
          # 機密情報を含む可能性のあるエラーメッセージをフィルタリング
          safe_message = filter_sensitive_info(error.message)
          flash[:alert] = "エラーが発生しました: #{safe_message}"
          redirect_to new_public_booking_path
        else
          flash[:alert] = "エラーが発生しました。管理者にお問い合わせください。"
          redirect_to admin_root_path 
        end
      }
      format.json { 
        render json: { 
          success: false, 
          error: "システムエラーが発生しました" 
        }, status: :internal_server_error 
      }
    end
  end
  
  def filter_sensitive_info(message)
    # 機密情報を含む可能性のあるパターンをフィルタリング
    filtered = message.dup
    filtered.gsub!(/password[=:]\S+/i, 'password=[FILTERED]')
    filtered.gsub!(/token[=:]\S+/i, 'token=[FILTERED]')
    filtered.gsub!(/secret[=:]\S+/i, 'secret=[FILTERED]')
    filtered.gsub!(/key[=:]\S+/i, 'key=[FILTERED]')
    filtered.gsub!(/line_user_id[=:]\S+/i, 'line_user_id=[FILTERED]')
    filtered.gsub!(/google_calendar_event_id[=:]\S+/i, 'google_calendar_event_id=[FILTERED]')
    filtered
  end

  def handle_not_found(error)
    respond_to do |format|
      format.html { 
        flash[:alert] = "指定されたデータが見つかりません。"
        # Public::BookingsControllerの場合は新規予約ページにリダイレクト
        if self.class.name.start_with?('Public::')
          redirect_to new_public_booking_path
        else
        redirect_to admin_root_path 
        end
      }
      format.json { 
        render json: { 
          success: false, 
          error: "データが見つかりません" 
        }, status: :not_found 
      }
    end
  end
end
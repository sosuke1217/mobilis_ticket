module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  end

  private

  def handle_standard_error(error)
    Rails.logger.error "#{error.class.name}: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")

    respond_to do |format|
      format.html { 
        # Public::BookingsControllerの場合は詳細なエラーメッセージを表示
        if self.class.name.start_with?('Public::')
          flash[:alert] = "エラーが発生しました: #{error.message}"
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
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
        flash[:alert] = "エラーが発生しました。管理者にお問い合わせください。"
        redirect_to admin_root_path 
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
        redirect_to admin_root_path 
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
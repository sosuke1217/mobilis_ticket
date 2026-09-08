class AdminUsers::TwoFactorController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :prevent_caching

  def show
  end

  def create
    code = params[:code].to_s
    if current_admin_user.verify_otp(code) || current_admin_user.consume_backup_code(code)
      session[:admin_two_factor_verified] = true
      redirect_to admin_root_path, notice: "二段階認証に成功しました。"
    else
      flash.now[:alert] = "認証コードが正しくありません。"
      render :show, status: :unprocessable_entity
    end
  end

  private

  def prevent_caching
    response.headers["Cache-Control"] = "no-store"
  end
end

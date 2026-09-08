class Admin::TwoFactorAuthenticationsController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :prevent_caching

  def show
    unless current_admin_user.otp_required_for_login?
      @secret = pending_secret || TotpService.generate_secret
      session[:pending_otp_secret] = current_admin_user.class.otp_encryptor.encrypt_and_sign(@secret)
      @provisioning_uri = TotpService.provisioning_uri(
        secret: @secret,
        account: current_admin_user.email
      )
    end
    @backup_codes = flash[:backup_codes]
  end

  def create
    secret = current_admin_user.class.otp_encryptor.decrypt_and_verify(session[:pending_otp_secret])
    unless TotpService.valid?(secret, params[:code])
      redirect_to admin_two_factor_authentication_path, alert: "6桁の認証コードが正しくありません。"
      return
    end

    current_admin_user.otp_secret = secret
    backup_codes = current_admin_user.generate_backup_codes
    current_admin_user.otp_required_for_login = true
    current_admin_user.save!
    session.delete(:pending_otp_secret)
    session[:admin_two_factor_verified] = true

    redirect_to admin_two_factor_authentication_path,
                notice: "二段階認証を有効にしました。",
                flash: { backup_codes: backup_codes }
  rescue ActiveSupport::MessageEncryptor::InvalidMessage, TypeError
    redirect_to admin_two_factor_authentication_path, alert: "設定の有効期限が切れました。もう一度お試しください。"
  end

  def destroy
    unless current_admin_user.valid_password?(params[:password]) && current_admin_user.verify_otp(params[:code])
      redirect_to admin_two_factor_authentication_path, alert: "パスワードまたは認証コードが正しくありません。"
      return
    end

    current_admin_user.update!(
      otp_required_for_login: false,
      otp_secret_ciphertext: nil,
      otp_backup_code_digests: []
    )
    session[:admin_two_factor_verified] = true
    redirect_to admin_two_factor_authentication_path, notice: "二段階認証を解除しました。"
  end

  private

  def pending_secret
    return if session[:pending_otp_secret].blank?

    current_admin_user.class.otp_encryptor.decrypt_and_verify(session[:pending_otp_secret])
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    session.delete(:pending_otp_secret)
    nil
  end

  def prevent_caching
    response.headers["Cache-Control"] = "no-store"
  end
end

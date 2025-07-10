class Admin::NotificationLogsController < ApplicationController
  before_action :authenticate_admin_user!

  def index
    @q = NotificationLog.ransack(params[:q])
    @notification_logs = @q.result.includes(:user, :ticket).order(sent_at: :desc)
                           .page(params[:page]).per(20)
  end

  def destroy
    @notification_log = NotificationLog.find(params[:id])
    @notification_log.destroy
    redirect_to admin_notification_logs_path, notice: "通知ログを削除しました。"
  end
  
end

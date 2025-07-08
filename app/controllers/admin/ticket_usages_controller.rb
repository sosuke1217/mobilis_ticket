class Admin::TicketUsagesController < ApplicationController
  before_action :authenticate_admin_user!
  helper Admin::TicketUsagesHelper
  require 'csv'

  def index
    @q = TicketUsage.ransack(params[:q])

    if params[:year_month].present?
      start_date = Date.strptime(params[:year_month], "%Y-%m").beginning_of_month
      end_date = start_date.end_of_month
      scoped = @q.result.includes(:ticket, :user).where(used_at: start_date..end_date)
    else
      scoped = @q.result.includes(:ticket, :user)
    end

    respond_to do |format|
      format.html do
        @ticket_usages = scoped.order(used_at: :desc).page(params[:page]).per(20)
      end

      format.csv do
        send_data generate_csv(scoped.order(used_at: :desc)),
                  filename: "ticket_usages_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
      end
    end
  end
  
  def new
    @usage = TicketUsage.new
    @users = User.all
    @tickets = Ticket.where("remaining_count > 0").includes(:user)
  end

  def create
    ticket = Ticket.find(params[:ticket_usage][:ticket_id])
    user = ticket.user
  
    if ticket.remaining_count > 0
      ticket.with_lock do
        ticket.remaining_count -= 1
        ticket.save!
  
        TicketUsage.create!(
          user: user,
          ticket: ticket,
          used_at: Time.current,
          note: params[:ticket_usage][:note] # ← メモを追加！
        )
      end
  
      redirect_to admin_ticket_usages_path, notice: "チケットを1回分消費しました。"
    else
      redirect_to new_admin_ticket_usage_path, alert: "チケットの残回数がありません。"
    end
  end
  
  def show
    @usage = TicketUsage.find(params[:id])
  end

  def edit
    @usage = TicketUsage.find(params[:id])
  end
  
  def update
    @usage = TicketUsage.find(params[:id])
    if @usage.update(ticket_usage_params)
      redirect_to admin_user_path(@usage.user), notice: "メモを更新しました。"
    else
      render :edit
    end
  end

  private

  def ticket_usage_params
    params.require(:ticket_usage).permit(:note)
  end

  def generate_csv(usages)
    CSV.generate(headers: true) do |csv|
      # ヘッダー行（カラム名）
      csv << ["使用日時", "ユーザー名", "LINE ID", "チケット名", "テンプレート名"]
  
      # データ行
      usages.each do |usage|
        csv << [
          usage.used_at&.strftime("%Y-%m-%d %H:%M"),
          usage.user&.name.presence || "未登録",
          usage.user&.line_user_id || "未連携",
          usage.ticket&.title || "不明",
          usage.ticket&.ticket_template&.name || "不明"
        ]
      end
    end
  end
end

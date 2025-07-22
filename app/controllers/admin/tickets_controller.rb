class Admin::TicketsController < ApplicationController
  before_action :authenticate_admin_user!
  require 'csv'

  def index
    # 検索パラメータをコピー
    @q_params = params[:q]&.dup || {}
  
    # カスタムステータスをransack用に変換
    case @q_params[:remaining_status]
    when "used"
      @q_params[:remaining_count_eq] = 0
    when "unused"
      @q_params[:remaining_count_gt] = 0
    end
  
    # ransackにない独自項目は削除
    @q_params.delete(:remaining_status)
  
    # 検索・絞り込み
    @q = Ticket.ransack(@q_params)
    scoped = @q.result.includes(:user, :ticket_template).order(created_at: :desc)
  
    respond_to do |format|
      format.html do
        @tickets = scoped.page(params[:page]).per(20)
      end
  
      format.csv do
        # ✅ ステータス絞り込み後の scoped をCSVに渡す
        send_data generate_csv(scoped),
                  filename: "tickets_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
      end
    end
  end
  
  
  

  def create
    @ticket = Ticket.new(ticket_params)
    @ticket.remaining_count = @ticket.total_count
  
    if @ticket.save
      redirect_to admin_tickets_path, notice: "チケットを作成しました"
    else
      @users = User.all
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @ticket = Ticket.find(params[:id])
  end

  def use
    @ticket = Ticket.find(params[:id])
  
    if @ticket.use_one
      TicketUsage.create!(
        ticket: @ticket,
        user: @ticket.user,
        used_at: Time.zone.now
      )
  
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to admin_user_path(@ticket.user), notice: "チケットを使用しました。" }
        format.json { render json: { remaining_count: @ticket.remaining_count } }
      end
    else
      respond_to do |format|
        format.html { redirect_to admin_user_path(@ticket.user), alert: "残回数がありません。" }
        format.json { render json: { error: "残回数がありません" }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @ticket = Ticket.find(params[:id])
    @user = @ticket.user
    @ticket_id = @ticket.id
    @ticket.destroy
  
    respond_to do |format|
      format.turbo_stream # ← これで destroy.turbo_stream.erb を探しに行く
      format.html { redirect_to admin_user_path(@user), notice: "チケットを削除しました" }
    end
  end

  def create_from_template
    @user = User.find(params[:user_id])
    template = TicketTemplate.find(params[:template_id])
  
    @ticket = @user.tickets.build(
      title: template.name,
      total_count: template.total_count,
      remaining_count: template.total_count,
      purchase_date: Time.zone.today,
      expiry_date: Time.zone.today + template.expiry_days.days,
      ticket_template_id: template.id
    )
  
    if @ticket.save
      respond_to do |format|
        format.turbo_stream  # 👈 これで create_from_template.turbo_stream.erb を使う
        format.html { redirect_to admin_user_path(@user), notice: "チケットを発行しました" }
      end
    else
      respond_to do |format|
        format.html { redirect_to admin_user_path(@user), alert: "発行に失敗しました: #{@ticket.errors.full_messages.join(', ')}" }
      end
    end
  end
  
  
  private

  def ticket_params
    params.require(:ticket).permit(:ticket_template_id, :total_count, :remaining_count, :purchase_date, :expiry_date, :user_id)
  end

  def generate_csv(tickets)
    CSV.generate(headers: true, encoding: 'UTF-8') do |csv|
      csv << ["ID", "ユーザー名", "LINE ID", "チケット名", "テンプレート名", "購入日", "有効期限", "残回数", "総回数", "ステータス"]
  
      tickets.each do |ticket|
        status = ticket.remaining_count > 0 ? "未使用あり" : "すべて使用済み"
  
        csv << [
          ticket.id,
          ticket.user&.name,
          ticket.user&.line_user_id,
          ticket.title,
          ticket.ticket_template&.name,
          ticket.purchase_date,
          ticket.expiry_date,
          ticket.remaining_count,
          ticket.total_count,
          status
        ]
      end
    end
  end
end
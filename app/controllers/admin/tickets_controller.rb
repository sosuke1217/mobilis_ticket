class Admin::TicketsController < ApplicationController
  before_action :authenticate_admin_user!
  # create_from_template アクションの上に追加
  skip_before_action :verify_authenticity_token, only: [:create_from_template]
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
    Rails.logger.info "🎫 [TICKET] create_from_template started"
    Rails.logger.info "🎫 [TICKET] user_id: #{params[:user_id]}, template_id: #{params[:template_id]}"
    
    @user = User.find(params[:user_id])
    template = TicketTemplate.find(params[:template_id])
    
    Rails.logger.info "🎫 [TICKET] User: #{@user.name}, Template: #{template.name}"
    
    # 発行前のアクティブチケット数を確認
    active_tickets_before = @user.tickets.where("remaining_count > 0").count
    Rails.logger.info "🎫 [TICKET] Active tickets BEFORE creation: #{active_tickets_before}"
  
    @ticket = @user.tickets.build(
      title: template.name,
      total_count: template.total_count,
      remaining_count: template.total_count,
      purchase_date: Time.zone.today,
      expiry_date: Time.zone.today + template.expiry_days.days,
      ticket_template_id: template.id
    )
  
    if @ticket.save
      Rails.logger.info "🎫 [TICKET] Saved successfully, ID: #{@ticket.id}"
      
      # 発行後のアクティブチケット数を確認
      active_tickets_after = @user.tickets.where("remaining_count > 0").order(expiry_date: :asc)
      Rails.logger.info "🎫 [TICKET] Active tickets AFTER creation: #{active_tickets_after.count}"
      
      respond_to do |format|
        format.html do
          Rails.logger.info "🎫 [TICKET] Redirecting to user page with notice"
          redirect_to admin_user_path(@user), notice: "チケットを発行しました"
        end
        format.turbo_stream do
          Rails.logger.info "🎫 [TICKET] Responding with Turbo Stream"
          
          if active_tickets_before == 0
            # 初回発行時（チケットがなかった状態から初回発行）
            Rails.logger.info "🎫 [TICKET] First ticket ever - replacing entire section"
            
            render turbo_stream: turbo_stream.update("active_ticket_section", 
              partial: "admin/tickets/partials/ticket_table", 
              locals: { tickets: active_tickets_after }
            )
          else
            # 追加発行時（既存テーブルに行を追加）
            Rails.logger.info "🎫 [TICKET] Additional ticket - appending row to existing table"
            Rails.logger.info "🎫 [TICKET] Looking for element: active_ticket_table_body"
            
            render turbo_stream: [
              turbo_stream.remove("ticket_#{@ticket.id}"),
              turbo_stream.append("active_ticket_table_body", 
                partial: "admin/tickets/partials/ticket_row", 
                locals: { ticket: @ticket }
              )
            ]
          end
        end
      end
    else
      Rails.logger.error "🎫 [TICKET] Save failed: #{@ticket.errors.full_messages.join(', ')}"
      
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash", "<div class='alert alert-danger alert-dismissible fade show'>発行に失敗しました: #{@ticket.errors.full_messages.join(', ')}</div>")
        end
        format.html do
          redirect_to admin_user_path(@user), alert: "発行に失敗しました: #{@ticket.errors.full_messages.join(', ')}"
        end
      end
    end
  rescue => e
    Rails.logger.error "🎫 [TICKET] Exception: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("flash", "<div class='alert alert-danger alert-dismissible fade show'>エラーが発生しました: #{e.message}</div>")
      end
      format.html do
        redirect_to admin_user_path(@user), alert: "エラーが発生しました"
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
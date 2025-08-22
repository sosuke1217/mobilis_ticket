class Admin::TicketsController < ApplicationController
  before_action :authenticate_admin_user!
  # create_from_template アクションの上に追加
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
    @user = @ticket.user
  
    if @ticket.use_one
      TicketUsage.create!(
        ticket: @ticket,
        user: @ticket.user,
        used_at: Time.zone.now
      )
  
      respond_to do |format|
        format.turbo_stream # これで use.turbo_stream.erb を探す
        format.json { render json: { remaining_count: @ticket.remaining_count } }
        format.html do
          # リファラーを確認してリダイレクト先を決定
          if request.referer&.include?('ticket_management')
            redirect_to admin_user_ticket_management_path(@user), notice: "チケットを使用しました。"
          else
            redirect_to admin_user_path(@user), notice: "チケットを使用しました。"
          end
        end
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash", 
            content_tag(:div, "残回数がありません。", class: "alert alert-danger alert-dismissible fade show"))
        end
        format.json { render json: { error: "残回数がありません" }, status: :unprocessable_entity }
        format.html do
          if request.referer&.include?('ticket_management')
            redirect_to admin_user_ticket_management_path(@user), alert: "残回数がありません。"
          else
            redirect_to admin_user_path(@user), alert: "残回数がありません。"
          end
        end
      end
    end
  end

  def destroy
    @ticket = Ticket.find(params[:id])
    @user = @ticket.user
    @ticket_id = @ticket.id
    @ticket.destroy
  
    respond_to do |format|
      format.json { render json: { success: true, message: "チケットを削除しました" } }
      format.turbo_stream # これで destroy.turbo_stream.erb を探す
      format.html do
        # リファラーを確認してリダイレクト先を決定
        if request.referer&.include?('ticket_management')
          redirect_to admin_user_ticket_management_path(@user), notice: "チケットを削除しました"
        else
          redirect_to admin_user_path(@user), notice: "チケットを削除しました"
        end
      end
    end
  end

  def create_from_template
    @user = User.find(params[:user_id])
    template = TicketTemplate.find(params[:template_id])
    
    # 発行前のアクティブチケット数を確認
    active_tickets_before = @user.tickets.where("remaining_count > 0").count
  
    @ticket = @user.tickets.build(
      title: template.name,
      total_count: template.total_count,
      remaining_count: template.total_count,
      purchase_date: Time.zone.today,
      expiry_date: Time.zone.today + template.expiry_days.days,
      ticket_template_id: template.id
    )
  
    if @ticket.save
      # 発行後のアクティブチケット数を確認
      active_tickets_after = @user.tickets.where("remaining_count > 0").order(expiry_date: :asc)
      
      respond_to do |format|
        format.turbo_stream do
          if active_tickets_before == 0
            # 初回発行時（チケットがなかった状態から初回発行）
            render turbo_stream: turbo_stream.update("active_ticket_section", 
              partial: "admin/tickets/partials/ticket_table", 
              locals: { tickets: active_tickets_after }
            )
          else
            # 追加発行時（既存テーブルに行を追加）
            render turbo_stream: [
              turbo_stream.remove("ticket_#{@ticket.id}"),
              turbo_stream.append("active_ticket_table_body", 
                partial: "admin/tickets/partials/ticket_row", 
                locals: { ticket: @ticket }
              )
            ]
          end
        end
        format.html do
          # リファラーを確認してリダイレクト先を決定
          if request.referer&.include?('ticket_management')
            redirect_to admin_user_ticket_management_path(@user), notice: "チケットを発行しました"
          else
            redirect_to admin_user_path(@user), notice: "チケットを発行しました"
          end
        end
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash", 
            content_tag(:div, "発行に失敗しました: #{@ticket.errors.full_messages.join(', ')}", 
                       class: "alert alert-danger alert-dismissible fade show"))
        end
        format.html do
          if request.referer&.include?('ticket_management')
            redirect_to admin_user_ticket_management_path(@user), alert: "発行に失敗しました: #{@ticket.errors.full_messages.join(', ')}"
          else
            redirect_to admin_user_path(@user), alert: "発行に失敗しました: #{@ticket.errors.full_messages.join(', ')}"
          end
        end
      end
    end
  rescue => e
    Rails.logger.error "🎫 [TICKET] Exception: #{e.message}"
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("flash", 
          content_tag(:div, "エラーが発生しました: #{e.message}", 
                     class: "alert alert-danger alert-dismissible fade show"))
      end
      format.html do
        if request.referer&.include?('ticket_management')
          redirect_to admin_user_ticket_management_path(@user), alert: "エラーが発生しました"
        else
          redirect_to admin_user_path(@user), alert: "エラーが発生しました"
        end
      end
    end
  end

  # ユーザー固有のチケット発行API
  def create_for_user
    @user = User.find(params[:user_id])
    @ticket_template = TicketTemplate.find(params[:ticket_template_id])
    @count = params[:count].to_i || 1

    begin
      created_tickets = []
      @count.times do
        ticket = @user.tickets.create!(
          ticket_template: @ticket_template,
          total_count: @ticket_template.total_count,
          remaining_count: @ticket_template.total_count,
          purchase_date: Date.current,
          expiry_date: @ticket_template.expiry_days ? Date.current + @ticket_template.expiry_days.days : nil
        )
        created_tickets << ticket
      end

      # 最新のチケットの詳細情報を返す
      latest_ticket = created_tickets.last
      render json: { 
        success: true, 
        message: "#{@count}枚のチケットを発行しました",
        tickets_count: @user.tickets.count,
        ticket: {
          id: latest_ticket.id,
          ticket_template: {
            name: latest_ticket.ticket_template.name,
            price: latest_ticket.ticket_template.price
          },
          remaining_count: latest_ticket.remaining_count,
          total_count: latest_ticket.total_count,
          purchase_date: latest_ticket.purchase_date,
          expiry_date: latest_ticket.expiry_date
        }
      }
    rescue => e
      render json: { 
        success: false, 
        error: e.message 
      }, status: :unprocessable_entity
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
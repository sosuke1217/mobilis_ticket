class Admin::UsersController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :set_user, only: [:show, :edit, :update, :destroy, :tickets, :history, :ticket_management, :ticket_usages, :update_line_profile]

  def index
    @q = User.ransack(params[:q])
    @users = @q.result(distinct: true).order(:name).page(params[:page]).per(20)
    
    respond_to do |format|
      format.html
      format.json do
        # スタッフ一覧を返す（管理者以外）
        staff_users = User.where(admin: false).order(:name)
        render json: staff_users.map { |user| { id: user.id, name: user.name } }
      end
    end
  end

  def show
    @active_tickets = @user.tickets.where("remaining_count > 0").includes(:ticket_template)
    @total_usages = @user.ticket_usages.count
    @recent_reservations = @user.reservations.order(start_time: :desc).limit(5)
    @recent_usages = @user.ticket_usages.includes(:ticket, :reservation).order(created_at: :desc).limit(5)
    
    # 追加のインスタンス変数
    @last_used_at = @user.ticket_usages.order(used_at: :desc).limit(1).pluck(:used_at).first
    @active_ticket_types = @active_tickets.group(:title).count
    @recent_ticket_usages = @user.ticket_usages.includes(:ticket => :ticket_template).order(used_at: :desc).limit(10)
    @used_up_tickets = @user.tickets.where(remaining_count: 0).includes(:ticket_template)
  end

  def new
    @user = User.new
  end

  def create
    Rails.logger.info "Creating user with params: #{params[:user]}"
    Rails.logger.info "Request format: #{request.format}"
    Rails.logger.info "Content-Type: #{request.content_type}"
    Rails.logger.info "Permitted params: #{user_params}"
    
    @user = User.new(user_params)
    
    respond_to do |format|
      if @user.save
        Rails.logger.info "User created successfully: #{@user.id}"
        format.html { redirect_to admin_users_path, notice: 'ユーザーを作成しました' }
        format.json { render json: { success: true, user: @user }, status: :created }
      else
        Rails.logger.error "User creation failed: #{@user.errors.full_messages}"
        Rails.logger.error "User attributes: #{@user.attributes}"
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { success: false, errors: @user.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  rescue => e
    Rails.logger.error "Exception in create: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    respond_to do |format|
      format.html { redirect_to admin_users_path, alert: "ユーザー作成中にエラーが発生しました: #{e.message}" }
      format.json { render json: { success: false, errors: [e.message] }, status: :internal_server_error }
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to admin_users_path, notice: 'ユーザーを更新しました'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_path, notice: 'ユーザーを削除しました'
  end

  # 顧客検索API
  def search
    query = params[:query].to_s.strip
    
    if query.length < 2
      render json: { users: [] }
      return
    end
    
    # 名前、電話番号、メールで検索（SQLite対応）
    users = User.where(admin: false)
      .where("LOWER(name) LIKE ? OR LOWER(phone_number) LIKE ? OR LOWER(email) LIKE ?", 
             "%#{query.downcase}%", "%#{query.downcase}%", "%#{query.downcase}%")
      .order(:name)
      .limit(10)
    
    user_data = users.map do |user|
      {
        id: user.id,
        name: user.name,
        phone_number: user.phone_number,
        email: user.email,
        active_tickets: user.tickets.where("remaining_count > 0").count,
        last_visit: user.reservations.order(start_time: :desc).limit(1).pluck(:start_time).first&.strftime('%Y-%m-%d')
      }
    end
    
    render json: { users: user_data }
  end

  # 回数券一覧API
  def tickets
    respond_to do |format|
      format.json do
        tickets = Ticket.where(user: @user).includes(:ticket_template)
        
        ticket_data = tickets.map do |ticket|
          {
            id: ticket.id,
            name: ticket.ticket_template.name,
            remaining: ticket.remaining_count,
            total: ticket.ticket_template.total_count,
            expires_at: ticket.expiry_date&.strftime('%Y-%m-%d'),
            status: get_ticket_status(ticket),
            price: ticket.ticket_template.price
          }
        end
        
        render json: ticket_data
      end
    end
  end

  # チケット管理ページ
  def ticket_management
    @tickets = @user.tickets.where("remaining_count > 0").includes(:ticket_template)
    @ticket_templates = TicketTemplate.all
  end

  # ユーザー固有のチケット使用履歴
  def ticket_usages
    @ticket_usages = @user.ticket_usages.includes(:ticket, :reservation).order(created_at: :desc).page(params[:page]).per(20)
  end

  # 顧客履歴API
  def history
    respond_to do |format|
      format.json do
        # 予約履歴
        reservations = Reservation.where(user: @user)
          .order(start_time: :desc)
          .limit(20)
        
        # 回数券使用履歴
        ticket_usages = TicketUsage.where(user: @user)
          .includes(:ticket, :reservation)
          .order(created_at: :desc)
          .limit(20)
        
        history_data = []
        
        # 予約履歴を追加
        reservations.each do |reservation|
          history_data << {
            type: 'reservation',
            date: reservation.start_time.strftime('%Y-%m-%d'),
            time: reservation.start_time.strftime('%H:%M'),
            status: reservation.status,
            course: reservation.course,
            staff: reservation.user&.name || '未設定',
            note: reservation.note
          }
        end
        
        # 回数券使用履歴を追加
        ticket_usages.each do |usage|
          history_data << {
            type: 'ticket_usage',
            date: usage.created_at.strftime('%Y-%m-%d'),
            time: usage.created_at.strftime('%H:%M'),
            status: 'completed',
            course: usage.ticket.ticket_template.name,
            staff: usage.reservation&.user&.name || '未設定',
            note: usage.note
          }
        end
        
        # 日時でソート
        history_data.sort_by! { |h| [h[:date], h[:time]] }.reverse!
        
        render json: history_data
      end
    end
  end

  def update_line_profile
    if @user.line_user_id.present? && @user.line_user_id != ''
      begin
        Rails.logger.info "LINE情報更新開始: ユーザーID #{@user.id}, LINE ID #{@user.line_user_id}"
        
        # 環境変数の確認
        unless ENV['LINE_CHANNEL_SECRET'].present? && ENV['LINE_CHANNEL_TOKEN'].present?
          error_msg = "LINE API設定が不完全です"
          Rails.logger.error "#{error_msg}: LINE_CHANNEL_SECRET=#{ENV['LINE_CHANNEL_SECRET'].present?}, LINE_CHANNEL_TOKEN=#{ENV['LINE_CHANNEL_TOKEN'].present?}"
          respond_to do |format|
            format.html { redirect_to admin_user_path(@user), alert: error_msg }
            format.json { render json: { success: false, error: error_msg }, status: :unprocessable_entity }
          end
          return
        end
        
        # LINEボットコントローラーのメソッドを使用
        linebot_controller = LinebotController.new
        result = linebot_controller.send(:update_user_profile, @user, @user.line_user_id)
        
        if result
          Rails.logger.info "LINE情報更新成功: ユーザーID #{@user.id}"
          respond_to do |format|
            format.html { redirect_to admin_user_path(@user), notice: 'LINEユーザー情報を更新しました' }
            format.json { render json: { success: true, message: 'LINEユーザー情報を更新しました' } }
          end
        else
          Rails.logger.error "LINE情報更新失敗: ユーザーID #{@user.id}"
          respond_to do |format|
            format.html { redirect_to admin_user_path(@user), alert: 'LINEユーザー情報の更新に失敗しました' }
            format.json { render json: { success: false, error: 'LINEユーザー情報の更新に失敗しました' }, status: :unprocessable_entity }
          end
        end
      rescue => e
        Rails.logger.error "LINE情報更新例外: ユーザーID #{@user.id} - #{e.class}: #{e.message}"
        Rails.logger.error "バックトレース: #{e.backtrace.first(5).join("\n")}"
        
        respond_to do |format|
          format.html { redirect_to admin_user_path(@user), alert: "LINEユーザー情報の更新に失敗しました: #{e.message}" }
          format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
        end
      end
    else
      Rails.logger.warn "LINE情報更新試行: LINE連携されていないユーザー ID #{@user.id}"
      respond_to do |format|
        format.html { redirect_to admin_user_path(@user), alert: 'LINE連携されていないユーザーです' }
        format.json { render json: { success: false, error: 'LINE連携されていないユーザーです' }, status: :unprocessable_entity }
      end
    end
  end

  # LINE連携を作成
  def create_line_link
    line_user_id = params[:line_user_id]&.strip
    
    unless line_user_id.present?
      respond_to do |format|
        format.html { redirect_to admin_user_path(@user), alert: 'LINEユーザーIDが入力されていません' }
        format.json { render json: { success: false, error: 'LINEユーザーIDが入力されていません' }, status: :unprocessable_entity }
      end
      return
    end

    # 既に他のユーザーが連携しているかチェック（空文字列は除外）
    existing_user = User.where.not(line_user_id: ['', nil]).find_by(line_user_id: line_user_id)
    if existing_user && existing_user != @user
      respond_to do |format|
        format.html { redirect_to admin_user_path(@user), alert: "このLINEユーザーIDは既に他のユーザー（#{existing_user.name}）と連携されています" }
        format.json { render json: { success: false, error: "このLINEユーザーIDは既に他のユーザー（#{existing_user.name}）と連携されています" }, status: :unprocessable_entity }
      end
      return
    end

    begin
      # LINE連携を作成
      if @user.update(line_user_id: line_user_id)
        # LINEからプロフィール情報を取得して更新
        if ENV['LINE_CHANNEL_SECRET'].present? && ENV['LINE_CHANNEL_TOKEN'].present?
          linebot_controller = LinebotController.new
          linebot_controller.send(:update_user_profile, @user, line_user_id)
        end
        
        Rails.logger.info "LINE連携作成成功: ユーザーID #{@user.id}, LINE ID #{line_user_id}"
        
        respond_to do |format|
          format.html { redirect_to admin_user_path(@user), notice: 'LINE連携を作成しました' }
          format.json { render json: { success: true, message: 'LINE連携を作成しました' } }
        end
      else
        Rails.logger.error "LINE連携作成失敗: ユーザーID #{@user.id} - #{@user.errors.full_messages}"
        
        respond_to do |format|
          format.html { redirect_to admin_user_path(@user), alert: "LINE連携の作成に失敗しました: #{@user.errors.full_messages.join(', ')}" }
          format.json { render json: { success: false, error: @user.errors.full_messages.join(', ') }, status: :unprocessable_entity }
        end
      end
    rescue => e
      Rails.logger.error "LINE連携作成例外: ユーザーID #{@user.id} - #{e.class}: #{e.message}"
      Rails.logger.error "バックトレース: #{e.backtrace.first(5).join("\n")}"
      
      respond_to do |format|
        format.html { redirect_to admin_user_path(@user), alert: "LINE連携の作成に失敗しました: #{e.message}" }
        format.json { render json: { success: false, error: e.message }, status: :internal_server_error }
      end
    end
  end

  # LINE連携を削除
  def remove_line_link
    unless @user.line_user_id.present?
      respond_to do |format|
        format.html { redirect_to admin_user_path(@user), alert: 'LINE連携されていないユーザーです' }
        format.json { render json: { success: false, error: 'LINE連携されていないユーザーです' }, status: :unprocessable_entity }
      end
      return
    end

    begin
      line_user_id = @user.line_user_id
      
      # LINE連携を削除（line_user_idを空文字列に設定）
      if @user.update(line_user_id: '')
        # LINEプロフィール情報もクリア（空文字列を使用）
        @user.update(
          display_name: '',
          status_message: '',
          language: ''
        )
        
        Rails.logger.info "LINE連携削除成功: ユーザーID #{@user.id}, LINE ID #{line_user_id}"
        
        respond_to do |format|
          format.html { redirect_to admin_user_path(@user), notice: 'LINE連携を削除しました' }
          format.json { render json: { success: true, message: 'LINE連携を削除しました' } }
        end
      else
        Rails.logger.error "LINE連携削除失敗: ユーザーID #{@user.id} - #{@user.errors.full_messages}"
        
        respond_to do |format|
          format.html { redirect_to admin_user_path(@user), alert: "LINE連携の削除に失敗しました: #{@user.errors.full_messages.join(', ')}" }
          format.json { render json: { success: false, error: @user.errors.full_messages.join(', ') }, status: :unprocessable_entity }
        end
      end
    rescue => e
      Rails.logger.error "LINE連携削除例外: ユーザーID #{@user.id} - #{e.class}: #{e.message}"
      Rails.logger.error "バックトレース: #{e.backtrace.first(5).join("\n")}"
      
      respond_to do |format|
        format.html { redirect_to admin_user_path(@user), alert: "LINE連携の削除に失敗しました: #{e.message}" }
        format.json { render json: { success: false, error: e.message }, status: :internal_server_error }
      end
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(
      :name, :kana, :phone_number, :email, :birth_date, :postal_code, :address, :admin_memo
    )
  end

  def get_ticket_status(ticket)
            if ticket.expiry_date && ticket.expiry_date < Date.current
      'expired'
    elsif ticket.remaining_count <= 0
      'used'
    elsif ticket.remaining_count <= 2
      'low'
    else
      'available'
    end
  end
end
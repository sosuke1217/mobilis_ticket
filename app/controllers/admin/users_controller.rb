class Admin::UsersController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :set_user, only: [:edit, :update, :show, :destroy]

  def index
    @q = User.ransack(params[:q])
    @users = @q.result(distinct: true).order(created_at: :desc).page(params[:page]).per(20)
  
    respond_to do |format|
      format.html # HTML表示用（テーブルなど）
      format.json { render json: @users.limit(1000).map { |u| { id: u.id, name: u.name } } }
    end
  end
  
  def show
    @active_tickets = @user.tickets.where("remaining_count > 0").order(expiry_date: :asc)
    @used_up_tickets = @user.tickets.where(remaining_count: 0).order(expiry_date: :desc)
    @ticket_templates = TicketTemplate.all
    @total_usages = @user.ticket_usages.count
    @last_used_at = @user.ticket_usages.order(used_at: :desc).limit(1).pluck(:used_at).first
    @active_ticket_types = @active_tickets.group(:title).count
    @recent_ticket_usages = @user.ticket_usages.includes(:ticket).order(used_at: :desc).limit(10)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    
    Rails.logger.info "🆕 Creating new user: #{@user.name}"
    
    if @user.save
      Rails.logger.info "✅ User created successfully: #{@user.name} (ID: #{@user.id})"
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: true, 
            message: "ユーザーを作成しました",
            user: {
              id: @user.id,
              name: @user.name,
              created_at: @user.created_at
            }
          }, status: :created 
        }
        format.html { 
          redirect_to admin_user_path(@user), notice: "ユーザー「#{@user.name}」を作成しました" 
        }
      end
    else
      Rails.logger.error "❌ User creation failed: #{@user.errors.full_messages}"
      
      respond_to do |format|
        format.json { 
          render json: { 
            success: false, 
            errors: @user.errors.full_messages 
          }, status: :unprocessable_entity 
        }
        format.html { 
          render :new, status: :unprocessable_entity 
        }
      end
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: "ユーザー情報を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    user_name = @user.name.presence || @user.line_user_id || "ID:#{@user.id}"
    
    begin
      # 削除前に関連データの数を取得（ログ用）
      tickets_count = @user.tickets.count
      usages_count = @user.ticket_usages.count
      reservations_count = Reservation.where(user_id: @user.id).count
      remaining_value = @user.remaining_ticket_value
      
      Rails.logger.info "🗑️ Deleting user: #{user_name}"
      Rails.logger.info "   - Tickets: #{tickets_count}"
      Rails.logger.info "   - Ticket usages: #{usages_count}"
      Rails.logger.info "   - Reservations: #{reservations_count}"
      Rails.logger.info "   - Remaining value: ¥#{remaining_value}"
      
      # ユーザーを削除（dependent: :destroyにより関連データも自動削除）
      @user.destroy!
      
      Rails.logger.info "✅ User deleted successfully: #{user_name}"
      
      success_message = "ユーザー「#{user_name}」を削除しました。"
      if tickets_count > 0 || usages_count > 0 || reservations_count > 0
        success_message += "関連データ: チケット#{tickets_count}件、使用履歴#{usages_count}件、予約#{reservations_count}件も処理されました。"
      end
      
      respond_to do |format|
        format.html { redirect_to admin_users_path, notice: success_message }
        format.json { render json: { success: true, message: success_message, redirect_url: admin_users_path } }
      end
      
    rescue ActiveRecord::InvalidForeignKey => e
      Rails.logger.error "❌ Foreign key constraint error: #{e.message}"
      error_message = "このユーザーは他のデータから参照されているため削除できません。"
      
      respond_to do |format|
        format.html { redirect_to admin_user_path(@user), alert: error_message }
        format.json { render json: { success: false, error: error_message }, status: :unprocessable_entity }
      end
      
    rescue ActiveRecord::RecordNotDestroyed => e
      Rails.logger.error "❌ User deletion failed: #{e.record.errors.full_messages}"
      error_message = "ユーザーの削除に失敗しました: #{e.record.errors.full_messages.join(', ')}"
      
      respond_to do |format|
        format.html { redirect_to admin_user_path(@user), alert: error_message }
        format.json { render json: { success: false, error: error_message }, status: :unprocessable_entity }
      end
      
    rescue => e
      Rails.logger.error "❌ Unexpected error during user deletion: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      error_message = "削除中に予期しないエラーが発生しました。"
      
      respond_to do |format|
        format.html { redirect_to admin_user_path(@user), alert: error_message }
        format.json { render json: { success: false, error: error_message }, status: :internal_server_error }
      end
    end
  end

  def ticket_usages
    @user = User.find(params[:user_id])
    @q = @user.ticket_usages.includes(:ticket).ransack(params[:q])
    @usages = @q.result.order(used_at: :desc).page(params[:page]).per(30)
  end
  
  def tickets
    @user = User.find(params[:user_id])
    @active_tickets = @user.tickets.active
    @used_up_tickets = @user.tickets.used_up
    @ticket_templates = TicketTemplate.all
  end  

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :admin, :admin_memo, :birth_date, :postal_code, :address, :phone_number, :email)
  end
end
class Admin::UsersController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :set_user, only: [:edit, :update]

  def index
    @q = User.ransack(params[:q])
    @users = @q.result(distinct: true).order(created_at: :desc).page(params[:page]).per(20)
  
    respond_to do |format|
      format.html # HTML表示用（テーブルなど）
      format.json { render json: @users.limit(1000).map { |u| { id: u.id, name: u.name } } }
    end
  end
  
  
  def show
    @user = User.find(params[:id])
  
    @active_tickets = @user.tickets.where("remaining_count > 0").order(expiry_date: :asc)
    @used_up_tickets = @user.tickets.where(remaining_count: 0).order(expiry_date: :desc)
    @ticket_templates = TicketTemplate.all
    @total_usages = @user.ticket_usages.count
    @last_used_at = @user.ticket_usages.order(used_at: :desc).limit(1).pluck(:used_at).first
    @active_ticket_types = @active_tickets.group(:title).count
    @recent_ticket_usages = @user.ticket_usages.includes(:ticket).order(used_at: :desc).limit(10)

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
    params.require(:user).permit(:name, :admin, :admin_memo, :birth_date, :postal_code, :address, :phone_number, :email) # 管理者だけadminも更新可能にしたいなら
  end
end
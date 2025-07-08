class UsersController < ApplicationController
  before_action :authenticate_admin_user!
  before_action :set_user, only: [:edit, :update]

  def index
    if params[:q].present?
      @users = User.where("name LIKE ?", "%#{params[:q]}%")
    else
      @users = User.all
    end
  end
  
  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to edit_user_path(@user), notice: "名前を更新しました。"
    else
      render :edit
    end
  end

  private
  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name)
  end
end

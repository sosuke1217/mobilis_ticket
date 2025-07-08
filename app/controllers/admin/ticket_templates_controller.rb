class Admin::TicketTemplatesController < ApplicationController
  before_action :authenticate_admin_user!
  def index
    @templates = TicketTemplate.all
  end

  def new
    @template = TicketTemplate.new
  end

  def create
    @template = TicketTemplate.new(template_params)
    if @template.save
      redirect_to admin_ticket_templates_path, notice: "テンプレートを作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @template = TicketTemplate.find(params[:id])
  end

  def update
    @template = TicketTemplate.find(params[:id])
    if @template.update(template_params)
      redirect_to admin_ticket_templates_path, notice: "テンプレートを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @template = TicketTemplate.find(params[:id])
    @template.destroy
    redirect_to admin_ticket_templates_path, notice: "テンプレートを削除しました"
  end

  private

  def template_params
    params.require(:ticket_template).permit(:name, :total_count, :expiry_days, :price)
  end
end
class Admin::DashboardController < ApplicationController
  layout "application"
  before_action :authenticate_admin_user!

  def index
    # 月選択（パラメータがない場合は今月）
    @selected_month = params[:month].present? ? Date.strptime(params[:month], "%Y-%m") : Date.current.beginning_of_month
  
    # セレクトタグ用の月リスト
    @available_months = TicketUsage.distinct
      .pluck(Arel.sql("strftime('%Y-%m', used_at)"))
      .compact
      .map { |m| Date.strptime(m, "%Y-%m") }
      .uniq
      .sort
      .reverse
  
    # 集計対象の範囲
    start_date = @selected_month.beginning_of_month
    end_date = @selected_month.end_of_month
    
    @monthly_issued_tickets = Ticket
      .includes(:ticket_template)
      .where(created_at: start_date..end_date)

    @total_sales_amount = @monthly_issued_tickets.sum do |ticket|
      ticket.ticket_template&.price.to_i
    end
  
    # テンプレートIDと名前で集計（IDがnilのときも考慮）
    raw_stats = TicketUsage
      .left_joins(ticket: :ticket_template)
      .where(used_at: start_date..end_date)
      .group("ticket_templates.id", "ticket_templates.name")
      .count
  
    # 整形：テンプレート名（または未設定）をキーに、countを値に
    @template_usage_stats = raw_stats.each_with_object({}) do |((id, name), count), hash|
      label = name || "テンプレート未設定"
      hash[label] ||= 0
      hash[label] += count
    end

    @total_usage_count = @template_usage_stats.values.sum

    template_names = @template_usage_stats.keys - ["テンプレート未設定"]
    # テンプレート名 → 単価（1回あたり）マップ
    @template_prices = TicketTemplate
      .where(name: template_names)
      .pluck(:name, :price, :total_count)
      .to_h { |name, price, total| [name, total.to_i > 0 ? (price.to_i / total) : 0] }

    # 消化金額合計（全行の合計）
    @total_sales = @template_usage_stats.sum do |template_name, count|
      unit_price = @template_prices[template_name].to_i
      unit_price * count
    end
  end
  
end

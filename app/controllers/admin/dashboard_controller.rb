# app/controllers/admin/dashboard_controller.rb の強化版

class Admin::DashboardController < ApplicationController
  layout "application"
  before_action :authenticate_admin_user!

  def index
    # 既存のチケット関連統計
    setup_ticket_statistics
    
    # 🆕 予約関連統計
    setup_reservation_statistics
    
    # 🆕 今日・明日の予定
    setup_daily_schedule
    
    # 🆕 アラート情報
    setup_alerts
  end

  # 指定された年でデータがある月を取得するAPI
  def month_options
    year = params[:year].to_i
    
    if year <= 0
      render json: { success: false, error: 'Invalid year' }
      return
    end
    
    year_start = Date.new(year, 1, 1)
    year_end = Date.new(year, 12, 31)
    
    # チケット発行データがある月を取得
    ticket_months = Ticket.where(created_at: year_start..year_end)
      .distinct
      .pluck(Arel.sql("EXTRACT(MONTH FROM created_at)"))
      .compact
      .map(&:to_i)
      .uniq
      .sort
    
    # チケット使用データがある月を取得
    usage_months = TicketUsage.where(used_at: year_start..year_end)
      .distinct
      .pluck(Arel.sql("EXTRACT(MONTH FROM used_at)"))
      .compact
      .map(&:to_i)
      .uniq
      .sort
    
    # 両方の月を結合して重複を除去
    all_months = (ticket_months + usage_months).uniq.sort
    
    render json: {
      success: true,
      year: year,
      months: all_months
    }
  end

  # 🆕 予約分析ページ
  def reservation_analytics
    @analytics = ReservationAnalytics.new(1.month.ago, Date.current)
    @basic_stats = @analytics.basic_stats
    @course_stats = @analytics.course_stats
    @customer_analysis = @analytics.customer_analysis
    @revenue_analysis = @analytics.revenue_analysis
    @weekday_analysis = @analytics.weekday_analysis
    @monthly_comparison = @analytics.monthly_comparison_report
  end

  private

  def setup_ticket_statistics
    # 年と月の選択（パラメータがない場合は今月）
    @selected_year = if params[:year].present?
      begin
        params[:year].to_i
      rescue ArgumentError
        Time.zone.today.year
      end
    else
      Time.zone.today.year
    end
    
    @selected_month = if params[:month].present?
      begin
        params[:month].to_i
      rescue ArgumentError
        Time.zone.today.month
      end
    else
      Time.zone.today.month
    end
    
    # 選択された年月でDateオブジェクトを作成
    @selected_date = Date.new(@selected_year, @selected_month, 1)
  
    # セレクトタグ用の年リスト（データがある年のみ）
    @available_years = []
    
    # チケット発行データがある年を取得
    ticket_years = Ticket.distinct
      .pluck(Arel.sql("EXTRACT(YEAR FROM created_at)"))
      .compact
      .map(&:to_i)
      .uniq
      .sort
      .reverse
    
    # チケット使用データがある年を取得
    usage_years = TicketUsage.distinct
      .pluck(Arel.sql("EXTRACT(YEAR FROM used_at)"))
      .compact
      .map(&:to_i)
      .uniq
      .sort
      .reverse
    
    # 両方の年を結合して重複を除去
    all_years = (ticket_years + usage_years).uniq.sort.reverse
    
    # 現在の年も含める（データがない場合でも選択可能にするため）
    current_year = Time.zone.today.year
    all_years = [current_year] + all_years unless all_years.include?(current_year)
    
    @available_years = all_years.map { |year| Date.new(year, 1, 1) }
    
    # セレクトタグ用の月リスト（データがある月のみ）
    @available_months = []
    
    # 選択された年でデータがある月を取得
    selected_year_start = Date.new(@selected_year, 1, 1)
    selected_year_end = Date.new(@selected_year, 12, 31)
    
    # チケット発行データがある月を取得
    ticket_months = Ticket.where(created_at: selected_year_start..selected_year_end)
      .distinct
      .pluck(Arel.sql("EXTRACT(MONTH FROM created_at)"))
      .compact
      .map(&:to_i)
      .uniq
      .sort
    
    # チケット使用データがある月を取得
    usage_months = TicketUsage.where(used_at: selected_year_start..selected_year_end)
      .distinct
      .pluck(Arel.sql("EXTRACT(MONTH FROM used_at)"))
      .compact
      .map(&:to_i)
      .uniq
      .sort
    
    # 両方の月を結合して重複を除去
    all_months = (ticket_months + usage_months).uniq.sort
    
    # データがない場合は1-12月を表示
    if all_months.empty?
      all_months = (1..12).to_a
    end
    
    @available_months = all_months.map { |month| Date.new(2000, month, 1) }
    
    # 集計対象の範囲
    start_date = @selected_date.beginning_of_month
    end_date = @selected_date.end_of_month
    
    @monthly_issued_tickets = Ticket
      .includes(:ticket_template, :user)
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

  def setup_reservation_statistics
    # 今月の予約統計
    current_month_start = Time.current.beginning_of_month
    current_month_end = Time.current.end_of_month
    
    @reservation_stats = {
      this_month: {
        total: Reservation.where(start_time: current_month_start..current_month_end).count,
        confirmed: Reservation.where(status: 'confirmed', start_time: current_month_start..current_month_end).count,
        cancelled: Reservation.where(status: 'cancelled', start_time: current_month_start..current_month_end).count,
        revenue: calculate_monthly_revenue(current_month_start, current_month_end)
      }
    }
    
    # 先月との比較
    last_month_start = 1.month.ago.beginning_of_month
    last_month_end = 1.month.ago.end_of_month
    
    @reservation_stats[:last_month] = {
      total: Reservation.where(start_time: last_month_start..last_month_end).count,
      confirmed: Reservation.where(status: 'confirmed', start_time: last_month_start..last_month_end).count,
      cancelled: Reservation.where(status: 'cancelled', start_time: last_month_start..last_month_end).count,
      revenue: calculate_monthly_revenue(last_month_start, last_month_end)
    }
    
    # 成長率計算
    @reservation_growth = {
      total: calculate_growth_rate(@reservation_stats[:last_month][:total], @reservation_stats[:this_month][:total]),
      confirmed: calculate_growth_rate(@reservation_stats[:last_month][:confirmed], @reservation_stats[:this_month][:confirmed]),
      revenue: calculate_growth_rate(@reservation_stats[:last_month][:revenue], @reservation_stats[:this_month][:revenue])
    }
    
    # 週別予約数（最近4週間）
    @weekly_reservations = []
    4.times do |i|
      week_start = (3-i).weeks.ago.beginning_of_week
      week_end = (3-i).weeks.ago.end_of_week
      @weekly_reservations << {
        week: "#{week_start.strftime('%m/%d')} - #{week_end.strftime('%m/%d')}",
        count: Reservation.where(status: 'confirmed', start_time: week_start..week_end).count
      }
    end
  end

  def setup_daily_schedule
    # 今日の予約
    @today_reservations = Reservation.where(status: 'confirmed')
      .where('DATE(start_time) = ?', Date.current)
      .includes(:user)
      .order(:start_time)
    
    # 明日の予約
    @tomorrow_reservations = Reservation.where(status: 'confirmed')
      .where('DATE(start_time) = ?', Date.tomorrow)
      .includes(:user)
      .order(:start_time)
    
    # 今週の予約数
    @this_week_count = Reservation.where(status: 'confirmed')
      .where('start_time >= ?', Date.current.beginning_of_week)
      .where('start_time <= ?', Date.current.end_of_week)
      .count
    
    # 利用率（今日）
    total_slots_today = 20 # 10:00-20:00を30分刻み
    booked_slots_today = @today_reservations.count
    @today_utilization = total_slots_today > 0 ? (booked_slots_today.to_f / total_slots_today * 100).round(1) : 0
  end

  def setup_alerts
    @alerts = []
    
    # 🚨 期限切れチケット
    expired_tickets = Ticket.where('expiry_date < ?', Date.current)
      .where('remaining_count > 0')
      .count
    if expired_tickets > 0
      @alerts << {
        type: 'danger',
        icon: 'fa-exclamation-triangle',
        message: "期限切れの未使用チケットが#{expired_tickets}件あります",
        action: 'お客様にご連絡をお願いします'
      }
    end
    
    # 🚨 今日の予約でチケット未消化
    today_completed = @today_reservations.select do |reservation|
      reservation.status == 'completed' && reservation.ticket_id.blank?
    end
    if today_completed.any?
      @alerts << {
        type: 'warning',
        icon: 'fa-ticket-alt',
        message: "本日完了した予約でチケット未消化が#{today_completed.count}件あります",
        action: 'チケット消化の処理をお願いします'
      }
    end
  end

  def calculate_monthly_revenue(start_date, end_date)
    course_prices = {
      "40分コース" => 8000,
      "60分コース" => 12000,
      "80分コース" => 16000
    }
    
    Reservation.where(status: 'confirmed', start_time: start_date..end_date)
      .sum { |reservation| course_prices[reservation.course] || 12000 }
  end

  def calculate_growth_rate(previous, current)
    return 0 if previous.zero?
    ((current - previous).to_f / previous * 100).round(1)
  end
end
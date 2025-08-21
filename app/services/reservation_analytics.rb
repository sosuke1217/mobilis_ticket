# app/services/reservation_analytics.rb

class ReservationAnalytics
  def initialize(start_date = 1.month.ago, end_date = Date.current)
    @start_date = start_date.beginning_of_day
    @end_date = end_date.end_of_day
  end

  # 📊 基本統計情報
  def basic_stats
    reservations = base_reservations
    
    {
      total_reservations: reservations.count,
      confirmed_reservations: reservations.confirmed.count,
      tentative_reservations: reservations.tentative.count,
      cancelled_reservations: reservations.cancelled.count,
      completed_reservations: reservations.completed.count,
      no_show_reservations: reservations.no_show.count,
      cancellation_rate: calculate_cancellation_rate(reservations),
      average_booking_lead_time: calculate_average_lead_time(reservations)
    }
  end

  # 📈 日別予約数
  def daily_bookings
    base_reservations
      .group_by_day(:start_time, time_zone: 'Tokyo')
      .group(:status)
      .count
  end

  # 🕐 時間帯別予約数
  def hourly_distribution
    base_reservations.active
      .group_by_hour(:start_time, time_zone: 'Tokyo')
      .count
  end

  # 📋 コース別統計
  def course_stats
    reservations = base_reservations.active
    
    {
      by_course: reservations.group(:course).count,
      revenue_by_course: calculate_revenue_by_course(reservations),
      average_duration_by_course: calculate_average_duration_by_course(reservations)
    }
  end

  # 👥 顧客分析
  def customer_analysis
    users_with_reservations = User.joins(:reservations)
      .where(reservations: { start_time: @start_date..@end_date })
      .distinct

    {
      total_customers: users_with_reservations.count,
      new_customers: new_customers_count,
      returning_customers: returning_customers_count,
      customer_retention_rate: calculate_retention_rate,
      average_reservations_per_customer: calculate_avg_reservations_per_customer,
      top_customers: top_customers(5)
    }
  end

  # 📅 曜日別分析
  def weekday_analysis
    reservations = base_reservations.active
    
    weekday_data = reservations
      .group("EXTRACT(DOW FROM start_time)")
      .count
    
    # 曜日名に変換
    weekday_names = %w[日 月 火 水 木 金 土]
    weekday_data.transform_keys { |key| weekday_names[key.to_i] }
  end

  # 🎯 予約効率分析
  def booking_efficiency
    available_slots = calculate_total_available_slots
    booked_slots = base_reservations.active.count
    
    {
      total_available_slots: available_slots,
      booked_slots: booked_slots,
      utilization_rate: (booked_slots.to_f / available_slots * 100).round(2),
      peak_hours: find_peak_hours,
      low_demand_hours: find_low_demand_hours
    }
  end

  # 💰 売上分析
  def revenue_analysis
    reservations = base_reservations.active
    
    course_prices = {
      "40分コース" => 8000,
      "60分コース" => 12000,
      "80分コース" => 16000
    }
    
    total_revenue = reservations.sum do |reservation|
      course_prices[reservation.course] || 12000 # デフォルト価格
    end
    
    {
      total_revenue: total_revenue,
      average_revenue_per_booking: (total_revenue.to_f / reservations.count).round(0),
      revenue_by_course: calculate_detailed_revenue_by_course(reservations, course_prices),
      daily_revenue: calculate_daily_revenue(reservations, course_prices)
    }
  end

  # 📊 月次比較レポート
  def monthly_comparison_report
    current_month = base_reservations
    previous_month = Reservation.where(
      start_time: (@start_date - 1.month)..(@end_date - 1.month)
    )
    
    current_stats = {
      total: current_month.count,
      confirmed: current_month.confirmed.count,
      revenue: calculate_total_revenue(current_month)
    }
    
    previous_stats = {
      total: previous_month.count,
      confirmed: previous_month.confirmed.count,
      revenue: calculate_total_revenue(previous_month)
    }
    
    {
      current_month: current_stats,
      previous_month: previous_stats,
      growth_rates: {
        reservations: calculate_growth_rate(previous_stats[:total], current_stats[:total]),
        confirmed: calculate_growth_rate(previous_stats[:confirmed], current_stats[:confirmed]),
        revenue: calculate_growth_rate(previous_stats[:revenue], current_stats[:revenue])
      }
    }
  end

  private

  def base_reservations
    @base_reservations ||= Reservation.where(start_time: @start_date..@end_date)
  end

  def calculate_cancellation_rate(reservations)
    total = reservations.count
    return 0 if total.zero?
    
    cancelled = reservations.cancelled.count + reservations.no_show.count
    (cancelled.to_f / total * 100).round(2)
  end

  def calculate_average_lead_time(reservations)
    lead_times = reservations.map do |reservation|
      (reservation.start_time.to_date - reservation.created_at.to_date).to_i
    end
    
    return 0 if lead_times.empty?
    (lead_times.sum.to_f / lead_times.count).round(1)
  end

  def calculate_revenue_by_course(reservations)
    course_prices = {
      "40分コース" => 8000,
      "60分コース" => 12000,
      "80分コース" => 16000
    }
    
    reservations.group(:course).count.transform_values do |count|
      count * (course_prices[reservations.first&.course] || 12000)
    end
  end

  def calculate_average_duration_by_course(reservations)
    reservations.group(:course).average(
      "(julianday(end_time) - julianday(start_time)) * 24 * 60"
    ).transform_values { |duration| duration&.round(0) }
  end

  def new_customers_count
    User.joins(:reservations)
      .where(reservations: { start_time: @start_date..@end_date })
      .where(created_at: @start_date..@end_date)
      .distinct
      .count
  end

  def returning_customers_count
    User.joins(:reservations)
      .where(reservations: { start_time: @start_date..@end_date })
      .where.not(created_at: @start_date..@end_date)
      .distinct
      .count
  end

  def calculate_retention_rate
    total_customers = User.joins(:reservations)
      .where(reservations: { start_time: (@start_date - 1.month)..(@end_date - 1.month) })
      .distinct
      .count
    
    return 0 if total_customers.zero?
    
    returning = User.joins(:reservations)
      .where(reservations: { start_time: (@start_date - 1.month)..(@end_date - 1.month) })
      .where(id: User.joins(:reservations)
        .where(reservations: { start_time: @start_date..@end_date })
        .distinct)
      .distinct
      .count
    
    (returning.to_f / total_customers * 100).round(2)
  end

  def calculate_avg_reservations_per_customer
    total_reservations = base_reservations.count
    total_customers = User.joins(:reservations)
      .where(reservations: { start_time: @start_date..@end_date })
      .distinct
      .count
    
    return 0 if total_customers.zero?
    (total_reservations.to_f / total_customers).round(2)
  end

  def top_customers(limit)
    User.joins(:reservations)
      .where(reservations: { start_time: @start_date..@end_date })
      .group('users.id, users.name')
      .order('COUNT(reservations.id) DESC')
      .limit(limit)
      .pluck('users.name, COUNT(reservations.id)')
      .map { |name, count| { name: name, reservation_count: count } }
  end

  def calculate_total_available_slots
    # 営業時間: 10:00-20:00 (10時間)
    # 30分刻み = 20スロット/日
    business_days = (@start_date.to_date..@end_date.to_date).count { |date| !date.sunday? }
    business_days * 20
  end

  def find_peak_hours
    hourly_data = base_reservations.active
      .group_by_hour(:start_time, time_zone: 'Tokyo')
      .count
    
    return [] if hourly_data.empty?
    
    max_bookings = hourly_data.values.max
    hourly_data.select { |_, count| count == max_bookings }.keys.map(&:hour)
  end

  def find_low_demand_hours
    hourly_data = base_reservations.active
      .group_by_hour(:start_time, time_zone: 'Tokyo')
      .count
    
    return [] if hourly_data.empty?
    
    min_bookings = hourly_data.values.min
    hourly_data.select { |_, count| count == min_bookings }.keys.map(&:hour)
  end

  def calculate_detailed_revenue_by_course(reservations, course_prices)
    reservations.group(:course).count.transform_keys do |course|
      {
        course: course,
        bookings: reservations.where(course: course).count,
        revenue: reservations.where(course: course).count * (course_prices[course] || 12000)
      }
    end
  end

  def calculate_daily_revenue(reservations, course_prices)
    reservations
      .group_by_day(:start_time, time_zone: 'Tokyo')
      .group(:course)
      .count
      .transform_values { |count| count * 12000 } # 簡易計算
  end

  def calculate_total_revenue(reservations)
    course_prices = {
      "40分コース" => 8000,
      "60分コース" => 12000,
      "80分コース" => 16000
    }
    
    reservations.sum do |reservation|
      course_prices[reservation.course] || 12000
    end
  end

  def calculate_growth_rate(previous, current)
    return 0 if previous.zero?
    ((current - previous).to_f / previous * 100).round(2)
  end
end
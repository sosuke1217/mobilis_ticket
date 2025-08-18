class Admin::TestController < ApplicationController
  before_action :authenticate_admin_user!

  def by_day_of_week
    Rails.logger.info "🔍 by_day_of_week called from TestController"
    Rails.logger.info "📝 Params: #{params.inspect}"
    
    begin
      day_of_week = params[:day_of_week].to_i
      from_date = Date.parse(params[:from_date])
      
      Rails.logger.info "🔍 Searching for reservations: day_of_week=#{day_of_week}, from_date=#{from_date}"
      
      # 指定日以降の全予約を取得してフィルタリング
      all_reservations = Reservation.includes(:user)
                                   .where('start_time >= ?', from_date.beginning_of_day)
                                   .where.not(status: :cancelled)
                                   .order(:start_time)
      
      # 曜日でフィルタリング
      matching_reservations = all_reservations.select { |r| r.start_time.wday == day_of_week }
      
      Rails.logger.info "📊 Found #{matching_reservations.count} reservations for day #{day_of_week} from #{from_date}"
      
      reservations_data = matching_reservations.map do |reservation|
        {
          id: reservation.id,
          customer: reservation.name || reservation.user&.name || '未設定',
          date: reservation.start_time.strftime('%Y-%m-%d'),
          time: reservation.start_time.strftime('%H:%M'),
          duration: extract_course_duration(reservation.course),
          effective_interval_minutes: reservation.individual_interval_minutes || 
                                     ApplicationSetting.current&.reservation_interval_minutes || 10
        }
      end
      
      Rails.logger.info "✅ Returning #{reservations_data.count} reservations for validation"
      
      render json: reservations_data
    rescue Date::Error => e
      Rails.logger.error "❌ Invalid date format: #{e.message}"
      render json: { error: 'Invalid date format' }, status: :bad_request
    rescue => e
      Rails.logger.error "❌ Error fetching reservations by day of week: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: 'Internal server error' }, status: :internal_server_error
    end
  end

  private

  def extract_course_duration(course)
    return 60 unless course.present?
    
    case course
    when /(\d+)分/
      $1.to_i
    when /1時間半/, /90分/
      90
    when /1時間/, /60分/
      60
    when /2時間/, /120分/
      120
    else
      60
    end
  end
end

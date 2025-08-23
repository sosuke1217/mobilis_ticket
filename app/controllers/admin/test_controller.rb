class Admin::TestController < ApplicationController
  before_action :authenticate_admin_user!

  def simple
    render json: { message: "Test controller works!", timestamp: Time.current }
  end

  def by_day_of_week_test
    day_of_week = params[:day_of_week].to_i
    from_date = params[:from_date]
    
    render json: {
      message: "by_day_of_week_test works!",
      day_of_week: day_of_week,
      from_date: from_date,
      timestamp: Time.current
    }
  end
end

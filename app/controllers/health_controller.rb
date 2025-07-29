class HealthController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def check
    health_status = SystemHealthChecker.perform_health_check
    
    if health_status[:overall_status] == :healthy
      render json: health_status, status: :ok
    else
      render json: health_status, status: :service_unavailable
    end
  end
  
  def detailed
    detailed_status = SystemHealthChecker.detailed_health_check
    render json: detailed_status
  end
end

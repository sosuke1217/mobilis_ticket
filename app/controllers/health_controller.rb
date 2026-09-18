class HealthController < ApplicationController
  skip_before_action :require_admin_two_factor!

  def check
    response.headers["Cache-Control"] = "no-store"

    if BookingHealthChecker.healthy?
      render json: { status: "ok" }, status: :ok
    else
      render json: { status: "unavailable" }, status: :service_unavailable
    end
  end
end

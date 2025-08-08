class SettingsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "settings_channel"
    Rails.logger.info "📡 Settings channel subscribed"
  end

  def unsubscribed
    Rails.logger.info "📡 Settings channel unsubscribed"
  end
end 
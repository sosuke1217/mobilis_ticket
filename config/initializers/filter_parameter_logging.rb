# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :password, :password_confirmation, :email, :secret, :token, :_key, :crypt, :salt, 
  :certificate, :otp, :ssn, :line_user_id, :google_calendar_event_id, :access_token, 
  :refresh_token, :api_key, :api_secret, :client_secret, :client_id, :signature,
  :code, :authorization_code, :google_calendar_synced_at, :token_hash
]

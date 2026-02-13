require_relative "boot"

require "rails/all"
require_relative "../lib/middleware/rate_limiter"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)
Dotenv::Rails.load if defined?(Dotenv)

module Mobilis
  class Application < Rails::Application
    config.load_defaults 7.2
    config.time_zone = 'Tokyo'
    # データベースも東京時間で保存するように変更
    config.active_record.default_timezone = :local
    
    # libディレクトリを自動ロード
    config.autoload_lib(ignore: %w(assets tasks))
    
    # 多言語対応の設定
    config.i18n.available_locales = [:ja, :en]
    config.i18n.default_locale = :ja
    config.i18n.fallbacks = true
    
    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks middleware])
    config.autoload_paths << Rails.root.join("lib")

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # レート制限（Rackミドルウェア）
    config.middleware.use RateLimiter unless Rails.env.development? || Rails.env.test?
    
    # セッション設定の強化
    config.session_store :cookie_store, 
                         key: '_mobilis_session',
                         httponly: true,
                         secure: Rails.env.production?,
                         same_site: :lax,
                         expire_after: 30.minutes
  end
end
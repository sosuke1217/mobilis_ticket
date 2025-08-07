ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    
    # 管理者ユーザーでログインするヘルパーメソッド
    def sign_in_admin_user(admin_user = nil)
      admin_user ||= admin_users(:one)
      post admin_user_session_path, params: { admin_user: { email: admin_user.email, password: 'password123' } }
    end
    
    # 一般ユーザーでログインするヘルパーメソッド
    def sign_in_user(user = nil)
      user ||= users(:one)
      # 一般ユーザーの認証システムがある場合はここに追加
    end
  end
end

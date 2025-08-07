require "test_helper"

class Admin::NotificationLogsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    sign_in_admin_user
    get admin_notification_logs_url
    assert_response :success
  end
end

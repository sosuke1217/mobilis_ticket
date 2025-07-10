require "test_helper"

class Admin::NotificationLogsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_notification_logs_index_url
    assert_response :success
  end
end

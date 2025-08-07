require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get edit" do
    sign_in_admin_user
    get edit_user_url(1)
    assert_response :success
  end

  test "should get update" do
    sign_in_admin_user
    patch user_url(1), params: { user: { name: "Updated Name" } }
    assert_response :redirect
  end
end

require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get edit" do
    sign_in_admin_user
    get edit_admin_user_url(1)
    assert_response :success
  end

  test "should get update" do
    sign_in_admin_user
    patch admin_user_url(1), params: { user: { name: "Updated Name" } }
    assert_response :redirect
  end

  test "should get index" do
    sign_in_admin_user
    get admin_users_url
    assert_response :success
  end
end

require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in AdminUser.create!(
      email: "user-merge-admin@example.com",
      password: "ValidPassword123!"
    )
  end

  test "merges and restores customer profiles" do
    source = User.create!(name: "Source", phone_number: "090-1234-5678", email: "source@example.com")
    target = User.create!(name: "Target", phone_number: "090-1234-5678")

    assert_difference -> { UserMerge.count }, 1 do
      post merge_users_admin_users_path,
           params: { source_user_id: source.id, target_user_id: target.id },
           as: :json
    end
    assert_response :success
    merge = UserMerge.order(:id).last
    assert_equal "Source (結合済み)", source.reload.name
    assert_equal "source@example.com", target.reload.email

    post undo_user_merge_admin_users_path(merge_id: merge.id)

    assert_redirected_to duplicate_candidates_admin_users_path
    assert_equal "Source", source.reload.name
    assert_equal "source@example.com", source.email
    assert_nil target.reload.email
    assert_equal "undone", merge.reload.status
  end

  test "does not merge a customer into itself" do
    user = User.create!(name: "Customer", phone_number: "09012345678")

    assert_no_difference -> { UserMerge.count } do
      post merge_users_admin_users_path,
           params: { source_user_id: user.id, target_user_id: user.id },
           as: :json
    end

    assert_response :unprocessable_entity
  end
end

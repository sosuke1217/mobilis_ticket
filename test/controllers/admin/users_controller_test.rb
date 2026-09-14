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

  test "merge button works after Turbo navigation without DOMContentLoaded" do
    user = User.create!(name: "Customer", phone_number: "09012345678")

    get admin_user_path(user)

    assert_response :success
    assert_select "#confirmMergeBtn[onclick='executeMerge()']"
  end

  test "shows an empty state when there are no duplicate customers" do
    get duplicate_candidates_admin_users_path

    assert_response :success
    assert_select ".alert-success", text: /重複候補はありません/
  end

  test "shows recent merge history with a localized timestamp" do
    source = User.create!(name: "Source", phone_number: "09011112222")
    target = User.create!(name: "Target", phone_number: "09033334444")
    UserMerge.create!(
      source_user: source,
      target_user: target,
      source_snapshot: { "name" => source.name },
      target_snapshot: { "name" => target.name }
    )

    get duplicate_candidates_admin_users_path

    assert_response :success
    assert_select "td", text: I18n.l(UserMerge.last.created_at, format: :short)
  end
end

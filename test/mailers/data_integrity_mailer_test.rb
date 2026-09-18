require "test_helper"

class DataIntegrityMailerTest < ActionMailer::TestCase
  test "contains counts and ids without customer data" do
    mail = DataIntegrityMailer.issues_found(
      invalid_ticket_balances: { count: 2, ids: [12, 34] }
    )

    assert_equal [ENV.fetch("ADMIN_EMAIL", "admin@mobilis-stretch.com")], mail.to
    assert_includes mail.subject, "データ整合性"
    assert_includes mail.body.decoded, "不正な回数券残数: 2件"
    assert_includes mail.body.decoded, "12, 34"
    assert_includes mail.body.decoded, "自動修正・削除は行っていません"
  end
end

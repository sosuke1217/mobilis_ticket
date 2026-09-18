require "test_helper"

class DataIntegrityCheckerTest < ActiveSupport::TestCase
  test "reports only operational identifiers for inconsistent records" do
    owner = User.create!(name: "Owner", phone_number: "09011112222")
    other = User.create!(name: "Other", phone_number: "09033334444")
    template = TicketTemplate.create!(name: "Four visits", total_count: 4, expiry_days: 90, price: 40_000)
    ticket = Ticket.create!(
      user: owner,
      ticket_template: template,
      total_count: 4,
      remaining_count: 4,
      purchase_date: Time.current,
      expiry_date: 90.days.from_now
    )
    ticket.update_columns(remaining_count: 5)
    usage = TicketUsage.create!(ticket: ticket, user: other, used_at: Time.current)

    start_time = 2.days.from_now.change(hour: 10, min: 0)
    missing_user = Reservation.create_as_admin!(
      course: "対面セッション（スタジオ／出張）",
      start_time: start_time,
      end_time: start_time + 60.minutes
    )
    first = Reservation.create_as_admin!(
      user: owner,
      course: "対面セッション（スタジオ／出張）",
      start_time: start_time,
      end_time: start_time + 60.minutes
    )
    second = Reservation.create_as_admin!(
      user: owner,
      course: "対面セッション（スタジオ／出張）",
      start_time: start_time,
      end_time: start_time + 60.minutes
    )

    issues = DataIntegrityChecker.call

    assert_equal [missing_user.id], issues[:upcoming_reservations_without_user][:ids]
    assert_equal [first.id, second.id].sort, issues[:duplicate_active_reservations][:ids].sort
    assert_equal [ticket.id], issues[:invalid_ticket_balances][:ids]
    assert_equal [usage.id], issues[:mismatched_ticket_usage_users][:ids]
  end

  test "returns no issues for consistent records" do
    assert_empty DataIntegrityChecker.call
  end
end

class DataIntegrityChecker
  SAMPLE_LIMIT = 50

  def self.call
    new.call
  end

  def call
    issues = {
      upcoming_reservations_without_user: issue_for(upcoming_reservations_without_user),
      duplicate_active_reservations: issue_for(duplicate_active_reservation_ids),
      invalid_ticket_balances: issue_for(invalid_ticket_balances),
      mismatched_ticket_usage_users: issue_for(mismatched_ticket_usage_users),
      incomplete_user_merges: issue_for(incomplete_user_merge_ids)
    }

    issues.reject { |_name, details| details[:count].zero? }
  end

  private

  def issue_for(ids)
    unique_ids = Array(ids).compact.uniq
    { count: unique_ids.length, ids: unique_ids.first(SAMPLE_LIMIT) }
  end

  def upcoming_reservations_without_user
    Reservation.active.where(user_id: nil).where("start_time >= ?", Time.current).pluck(:id)
  end

  def duplicate_active_reservation_ids
    duplicate_slots = Reservation.active
                                 .where.not(user_id: nil)
                                 .where("start_time >= ?", Time.current)
                                 .group(:user_id, :start_time)
                                 .having("COUNT(*) > 1")
                                 .pluck(:user_id, :start_time)

    duplicate_slots.flat_map do |user_id, start_time|
      Reservation.active.where(user_id: user_id, start_time: start_time).pluck(:id)
    end
  end

  def invalid_ticket_balances
    Ticket.where("remaining_count < 0 OR remaining_count > total_count").pluck(:id)
  end

  def mismatched_ticket_usage_users
    TicketUsage.joins(:ticket)
               .where("ticket_usages.user_id != tickets.user_id")
               .pluck(:id)
  end

  def incomplete_user_merge_ids
    UserMerge.where(status: "completed").filter_map do |merge|
      merge.id if merge_incomplete?(merge)
    end
  end

  def merge_incomplete?(merge)
    Reservation.where(id: merge.reservation_ids, user_id: merge.source_user_id).exists? ||
      Ticket.where(id: merge.ticket_ids, user_id: merge.source_user_id).exists? ||
      TicketUsage.where(id: merge.ticket_usage_ids, user_id: merge.source_user_id).exists? ||
      NotificationLog.where(id: merge.notification_log_ids, user_id: merge.source_user_id).exists?
  end
end

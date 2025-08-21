module Admin::TicketUsagesHelper
  def month_options
    TicketUsage
      .order(used_at: :desc)
      .pluck(Arel.sql("DISTINCT TO_CHAR(used_at, 'YYYY-MM')"))
      .map { |ym| [ym, ym] }
  end
end

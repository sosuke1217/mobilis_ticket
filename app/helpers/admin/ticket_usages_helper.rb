module Admin::TicketUsagesHelper
  def month_options
    TicketUsage
      .order(used_at: :desc)
      .pluck(Arel.sql("DISTINCT to_char(used_at, 'YYYY-MM')"))
      .map { |ym| [ym, ym] }
  end
end

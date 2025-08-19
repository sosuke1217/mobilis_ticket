module Admin::TicketUsagesHelper
  def month_options
    TicketUsage
      .order(used_at: :desc)
      .pluck(Arel.sql("DISTINCT strftime('%Y-%m', used_at)"))
      .map { |ym| [ym, ym] }
  end
end

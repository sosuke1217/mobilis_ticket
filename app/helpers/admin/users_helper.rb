module Admin::UsersHelper
  # LINE連携状態のバッジを返す
  def line_status_badge(user)
    if user.line_user_id.present? && user.line_user_id != ''
      content_tag(:span, class: "badge bg-success") do
        tag.i(class: "fab fa-line me-1") + "連携済み"
      end
    else
      content_tag(:span, class: "badge bg-secondary") do
        tag.i(class: "fas fa-unlink me-1") + "未連携"
      end
    end
  end

  # ユーザー名の表示（未登録の場合は「未登録」を表示）
  def display_user_name(user)
    if user.display_name_or_name.present?
      link_to user.display_name_or_name, admin_user_path(user), class: "text-decoration-none"
    else
      content_tag(:span, "未登録", class: "text-muted fst-italic")
    end
  end

  # 最終利用日の表示
  def display_last_usage_date(user)
    if user.last_usage_date
      content_tag(:div, class: "text-muted") do
        tag.i(class: "fas fa-calendar me-1") + user.last_usage_date.strftime("%m/%d")
      end
    else
      content_tag(:span, class: "text-muted small") do
        tag.i(class: "fas fa-minus me-1") + "未利用"
      end
    end
  end

  # チケット残数のバッジを返す
  def ticket_count_badge(user)
    return nil if user.active_ticket_count <= 0
    
    content_tag(:span, class: "badge bg-info") do
      tag.i(class: "fas fa-ticket-alt me-1") + "#{user.active_ticket_count}回"
    end
  end
end

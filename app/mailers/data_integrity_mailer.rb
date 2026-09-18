class DataIntegrityMailer < ApplicationMailer
  ISSUE_LABELS = {
    upcoming_reservations_without_user: "顧客に紐づいていない今後の予約",
    duplicate_active_reservations: "同一顧客・同一時刻の有効予約",
    invalid_ticket_balances: "不正な回数券残数",
    mismatched_ticket_usage_users: "回数券と顧客が一致しない利用履歴",
    incomplete_user_merges: "移動漏れの可能性がある顧客統合"
  }.freeze

  def issues_found(issues)
    @issues = issues

    mail(
      to: ENV.fetch("ADMIN_EMAIL", "admin@mobilis-stretch.com"),
      subject: "【Mobilis】データ整合性の確認が必要です"
    ) do |format|
      format.text { render plain: message_body }
    end
  end

  private

  def message_body
    details = @issues.map do |name, issue|
      label = ISSUE_LABELS.fetch(name.to_sym, name.to_s)
      "#{label}: #{issue[:count]}件（対象ID: #{issue[:ids].join(', ')}）"
    end.join("\n")

    <<~TEXT
      Mobilisのデータ整合性チェックで、確認が必要な項目を検知しました。

      #{details}

      データの自動修正・削除は行っていません。
      通知には氏名、メールアドレス、電話番号、住所、入力内容を含めていません。
      Mobilis Ticketの管理画面で対象IDを確認してください。
    TEXT
  end
end

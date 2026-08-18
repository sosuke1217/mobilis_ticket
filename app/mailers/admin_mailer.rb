class AdminMailer < ApplicationMailer
  def new_booking_request(reservation)
    @reservation = reservation
    @user = reservation.user

    mail(
      to: ENV.fetch("ADMIN_EMAIL", "admin@mobilis-stretch.com"),
      subject: "【新規仮予約】#{@user.name}様からの予約リクエスト"
    ) do |format|
      format.text { render plain: message_body }
    end
  end

  private

  def message_body
    <<~TEXT
      新しい仮予約が入りました。

      お客様名: #{@user.name}
      予約日時: #{@reservation.start_time.in_time_zone.strftime("%Y年%m月%d日 %H:%M")}〜#{@reservation.end_time.in_time_zone.strftime("%H:%M")}
      コース: #{@reservation.course}
      メール: #{@user.email.presence || "未登録"}
      電話番号: #{@user.phone_number.presence || "未登録"}
      住所: #{@user.address.presence || "未登録"}
      備考: #{@reservation.note.presence || "なし"}

      Mobilis Ticketの管理画面で予約内容を確認し、確定してください。
    TEXT
  end
end

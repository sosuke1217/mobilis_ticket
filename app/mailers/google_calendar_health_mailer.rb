class GoogleCalendarHealthMailer < ApplicationMailer
  def failure(health)
    @health = health

    mail(
      to: ENV.fetch("ADMIN_EMAIL", "admin@mobilis-stretch.com"),
      subject: "【Mobilis】Googleカレンダー接続エラー"
    ) do |format|
      format.text do
        render plain: <<~TEXT
          Googleカレンダーの空き状況を取得できませんでした。

          発生日時: #{@health.last_failure_at&.in_time_zone&.strftime("%Y年%m月%d日 %H:%M")}
          エラー: #{@health.last_error}

          Mobilis管理画面で接続テストを行い、必要に応じて再認証してください。
        TEXT
      end
    end
  end

  def recovered(health)
    @health = health

    mail(
      to: ENV.fetch("ADMIN_EMAIL", "admin@mobilis-stretch.com"),
      subject: "【Mobilis】Googleカレンダー接続が復旧しました"
    ) do |format|
      format.text do
        render plain: <<~TEXT
          Googleカレンダーとの接続が復旧しました。

          復旧確認日時: #{@health.last_success_at&.in_time_zone&.strftime("%Y年%m月%d日 %H:%M")}
        TEXT
      end
    end
  end
end

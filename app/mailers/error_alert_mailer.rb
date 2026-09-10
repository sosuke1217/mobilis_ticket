class ErrorAlertMailer < ApplicationMailer
  def failure(error_class:, source:, occurred_at:, context: {})
    @error_class = error_class
    @source = source
    @occurred_at = occurred_at
    @context = context

    mail(
      to: ENV.fetch("ADMIN_EMAIL", "admin@mobilis-stretch.com"),
      subject: "【Mobilis】システムエラーを検知しました"
    ) do |format|
      format.text { render plain: message_body }
    end
  end

  private

  def message_body
    details = @context.map { |key, value| "#{key}: #{value}" }.join("\n")

    <<~TEXT
      Mobilisでシステムエラーを検知しました。

      発生日時: #{@occurred_at.in_time_zone.strftime('%Y年%m月%d日 %H:%M:%S')}
      発生箇所: #{@source}
      エラー種別: #{@error_class}
      #{details.presence || '追加情報: なし'}

      お客様の氏名、メールアドレス、電話番号、住所、入力内容は通知に含めていません。
      詳細はHerokuのログでrequest_idを検索してください。
    TEXT
  end
end

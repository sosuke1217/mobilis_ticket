class ErrorAlertMailer < ApplicationMailer
  def failure(error_class:, error_summary:, root_cause_class:, application_frame:, release:, occurrence_count:, source:, occurred_at:, context: {})
    @error_class = error_class
    @error_summary = error_summary
    @root_cause_class = root_cause_class
    @application_frame = application_frame
    @release = release
    @occurrence_count = occurrence_count
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
      原因種別: #{@root_cause_class}
      安全な概要: #{@error_summary}
      アプリ内の発生行: #{@application_frame}
      デプロイ版: #{@release}
      同一エラー発生回数（24時間）: #{@occurrence_count}
      #{details.presence || '追加情報: なし'}

      お客様の氏名、メールアドレス、電話番号、住所、入力内容は通知に含めていません。
      さらに詳細な調査が必要な場合は、Herokuのログでrequest_idを検索してください。
    TEXT
  end
end

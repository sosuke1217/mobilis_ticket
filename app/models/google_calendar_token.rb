class GoogleCalendarToken < ApplicationRecord
  # トークンデータをJSONとして保存・取得
  def token_hash
    JSON.parse(token_data) if token_data.present?
  end

  def token_hash=(hash)
    self.token_data = hash.to_json
  end
end


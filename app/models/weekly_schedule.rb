class WeeklySchedule < ApplicationRecord
  validates :week_start_date, presence: true, uniqueness: true
  validates :schedule_data, presence: true
  
  # デフォルトの週スケジュールを取得
  def self.default_schedule
    find_by(is_recurring: true) || create_default_schedule
  end
  
  # 特定の週のスケジュールを取得
  def self.for_week(week_start_date)
    find_by(week_start_date: week_start_date) || default_schedule
  end
  
  # デフォルトスケジュールを作成
  def self.create_default_schedule
    default_data = {
      "0" => { "enabled" => false, "times" => [] }, # 日曜日
      "1" => { "enabled" => true, "times" => [{ "start" => "09:00", "end" => "20:00" }] }, # 月曜日
      "2" => { "enabled" => true, "times" => [{ "start" => "10:00", "end" => "20:00" }] }, # 火曜日
      "3" => { "enabled" => true, "times" => [{ "start" => "10:00", "end" => "20:00" }] }, # 水曜日
      "4" => { "enabled" => true, "times" => [{ "start" => "10:00", "end" => "20:00" }] }, # 木曜日
      "5" => { "enabled" => true, "times" => [{ "start" => "10:00", "end" => "20:00" }] }, # 金曜日
      "6" => { "enabled" => true, "times" => [{ "start" => "09:00", "end" => "18:00" }] }  # 土曜日
    }
    
    create!(
      week_start_date: Date.current.beginning_of_week,
      schedule_data: default_data,
      is_recurring: true,
      notes: "デフォルトの週間スケジュール"
    )
  end
  
  # スケジュールデータを取得（JavaScript形式に変換）
  def schedule_for_javascript
    schedule_data.deep_symbolize_keys
  end
  
  # 特定の曜日のスケジュールを取得
  def day_schedule(day_of_week)
    schedule_data[day_of_week.to_s] || { "enabled" => false, "times" => [] }
  end
  
  # 特定の曜日のスケジュールを更新
  def update_day_schedule(day_of_week, schedule)
    new_data = schedule_data.dup
    new_data[day_of_week.to_s] = schedule
    update!(schedule_data: new_data)
  end
end 
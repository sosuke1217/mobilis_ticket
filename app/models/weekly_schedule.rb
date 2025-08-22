class WeeklySchedule < ApplicationRecord
  validates :week_start_date, presence: true, uniqueness: true
  
  # デフォルトスケジュールを取得
  def self.default_schedule
    # デフォルトの営業時間設定
    {
      0 => { # 日曜日
        business_hours: [
          { start: '09:00', end: '18:00' }
        ]
      },
      1 => { # 月曜日
        business_hours: [
          { start: '09:00', end: '20:00' }
        ]
      },
      2 => { # 火曜日
        business_hours: [
          { start: '10:00', end: '20:00' }
        ]
      },
      3 => { # 水曜日
        business_hours: [
          { start: '10:00', end: '20:00' }
        ]
      },
      4 => { # 木曜日
        business_hours: [
          { start: '10:00', end: '20:00' }
        ]
      },
      5 => { # 金曜日
        business_hours: [
          { start: '10:00', end: '20:00' }
        ]
      },
      6 => { # 土曜日
        business_hours: [
          { start: '09:00', end: '18:00' }
        ]
      }
    }
  end
  
  # JavaScript用のスケジュール形式に変換
  def schedule_for_javascript
    schedule_data = {}
    
    (0..6).each do |day_of_week|
      day_schedule = schedule[day_of_week.to_s] || default_schedule[day_of_week]
      schedule_data[day_of_week] = day_schedule
    end
    
    schedule_data
  end
  
  private
  
  def default_schedule
    self.class.default_schedule
  end
end

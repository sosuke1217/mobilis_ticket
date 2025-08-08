module Admin::CalendarHelper
  # 営業時間の状態を取得
  def business_hours_status
    setting = ApplicationSetting.first
    return { open: false, hours: "10:00-21:00" } unless setting
    
    current_hour = Time.current.hour
    is_open = current_hour >= setting.business_hours_start && 
              current_hour < setting.business_hours_end
    
    {
      open: is_open,
      hours: setting.formatted_business_hours,
      start: setting.business_hours_start,
      end: setting.business_hours_end,
      status_class: is_open ? 'open' : 'closed'
    }
  end
  
  # 時間枠のCSSクラスを生成
  def time_slot_classes(hour)
    classes = ['fc-timegrid-slot']
    
    setting = ApplicationSetting.first
    return classes.join(' ') unless setting
    
    if hour >= setting.business_hours_start && hour < setting.business_hours_end
      classes << 'business-hour'
      
      # 時間帯別のクラス追加
      case hour
      when 6...10
        classes << 'morning-hour'
      when 10...12
        classes << 'late-morning-hour'
      when 12...17
        classes << 'afternoon-hour'
      when 17...21
        classes << 'evening-hour'
      else
        classes << 'night-hour'
      end
      
      # 営業開始/終了の境界
      classes << 'business-start' if hour == setting.business_hours_start
      classes << 'business-end' if hour == setting.business_hours_end - 1
    else
      classes << 'non-business-hour'
    end
    
    classes.join(' ')
  end
end 
puts "Creating ApplicationSetting..."

ApplicationSetting.find_or_create_by(id: 1) do |setting|
  setting.reservation_interval_minutes = 15
  setting.business_hours_start = 10
  setting.business_hours_end = 20
  setting.slot_interval_minutes = 30
  setting.max_advance_booking_days = 30
  setting.min_advance_booking_hours = 24
  setting.sunday_closed = true
  puts "✅ ApplicationSetting created with default values"
end

# 既存のApplicationSettingがある場合
if ApplicationSetting.exists?
  setting = ApplicationSetting.current
  puts "✅ ApplicationSetting already exists:"
  puts "   - Reservation interval: #{setting.reservation_interval_minutes} minutes"
  puts "   - Business hours: #{setting.business_hours_range}"
  puts "   - Slot interval: #{setting.slot_interval_minutes} minutes"
  puts "   - Sunday closed: #{setting.sunday_closed? ? 'Yes' : 'No'}"
end

puts "Seed completed! 🌱"
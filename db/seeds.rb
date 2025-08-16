# db/seeds.rb
puts "🌱 Seeding database..."

# Create ApplicationSetting if it doesn't exist
if ApplicationSetting.count == 0
  puts "📊 Creating ApplicationSetting..."
  ApplicationSetting.create!(
    reservation_interval_minutes: 10,
    business_hours_start: 10,
    business_hours_end: 20,
    slot_interval_minutes: 30,
    max_advance_booking_days: 30,
    min_advance_booking_hours: 24,
    sunday_closed: true
  )
  puts "✅ ApplicationSetting created"
else
  puts "✅ ApplicationSetting already exists"
end

# Create a default user if none exist
if User.count == 0
  puts "👤 Creating default user..."
  User.create!(
    name: "テストユーザー",
    email: "test@example.com",
    phone_number: "090-1234-5678",
    line_user_id: "test_line_user_id"
  )
  puts "✅ Default user created"
else
  puts "✅ Users already exist"
end

# Create a default admin user if none exist
if AdminUser.count == 0
  puts "👨‍💼 Creating default admin user..."
  AdminUser.create!(
    email: "admin@example.com",
    password: "password123",
    password_confirmation: "password123"
  )
  puts "✅ Default admin user created"
else
  puts "✅ Admin users already exist"
end

puts "🎉 Seeding completed!"
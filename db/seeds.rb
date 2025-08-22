# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Starting database seeding..."

# 管理者ユーザーの作成
admin_user = AdminUser.find_or_create_by!(email: 'admin@example.com') do |user|
  user.password = 'password123'
  user.password_confirmation = 'password123'
end
puts "✅ Admin user created: #{admin_user.email}"

# 一般ユーザーの作成
user = User.find_or_create_by!(email: 'user@example.com') do |u|
  u.name = 'テストユーザー'
  u.phone_number = '090-1234-5678'
  u.birth_date = Date.new(1990, 1, 1)
end
puts "✅ User created: #{user.name} (#{user.email})"

# チケットテンプレートの作成
ticket_template = TicketTemplate.find_or_create_by!(name: '60分コース') do |tt|
  tt.expiry_days = 365
  tt.price = 3000
end
puts "✅ Ticket template created: #{ticket_template.name}"

# チケットの作成
ticket = Ticket.find_or_create_by!(user: user, ticket_template: ticket_template) do |t|
  t.total_count = 10
  t.remaining_count = 10
  t.purchase_date = Date.current
  t.expiry_date = Date.current + 1.year
end
puts "✅ Ticket created: #{ticket.id}"

# アプリケーション設定の作成
app_setting = ApplicationSetting.find_or_create_by!(id: 1) do |as|
  as.reservation_interval_minutes = 15
end
puts "✅ Application setting created: interval=#{app_setting.reservation_interval_minutes} minutes"

# 予約の作成（テスト用）- 48時間後、10分刻みの時間
day_after_tomorrow = Time.current + 2.days
start_time = day_after_tomorrow.change(hour: 10, min: 0, sec: 0) # 10:00
end_time = start_time + 1.hour

reservation = Reservation.find_or_create_by!(start_time: start_time) do |r|
  r.user = user
  r.ticket = ticket
  r.course = '60分コース'
  r.end_time = end_time
  r.status = :confirmed
  r.note = 'テスト予約'
end
puts "✅ Reservation created: #{reservation.id} for #{reservation.start_time}"

puts "🎉 Database seeding completed!"
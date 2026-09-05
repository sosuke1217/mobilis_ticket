class ApplicationConfig
  BUSINESS_HOURS = {
    start: ENV.fetch('BUSINESS_HOURS_START', '10:00'),
    end: ENV.fetch('BUSINESS_HOURS_END', '20:00')
  }.freeze

  COURSE_PRICES = {
    "対面セッション（スタジオ／出張）" => ENV.fetch('PRICE_FACE_TO_FACE', 15000).to_i,
    "オンライン身体分析・設計" => ENV.fetch('PRICE_ONLINE', 5000).to_i,
    "40分コース" => ENV.fetch('PRICE_40MIN', 8000).to_i,
    "60分コース" => ENV.fetch('PRICE_60MIN', 12000).to_i,
    "80分コース" => ENV.fetch('PRICE_80MIN', 16000).to_i
  }.freeze

  BOOKING_LIMITS = {
    max_advance_days: ENV.fetch('MAX_ADVANCE_BOOKING_DAYS', 30).to_i,
    min_advance_hours: ENV.fetch('MIN_ADVANCE_BOOKING_HOURS', 24).to_i
  }.freeze
end

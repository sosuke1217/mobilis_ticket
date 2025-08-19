# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_08_18_124255) do
  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "application_settings", force: :cascade do |t|
    t.integer "reservation_interval_minutes", default: 15, null: false
    t.integer "business_hours_start", default: 10, null: false
    t.integer "business_hours_end", default: 20, null: false
    t.integer "slot_interval_minutes", default: 30, null: false
    t.integer "max_advance_booking_days", default: 30, null: false
    t.integer "min_advance_booking_hours", default: 24, null: false
    t.boolean "sunday_closed", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_application_settings_on_created_at"
  end

  create_table "notification_logs", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "ticket_id", null: false
    t.string "kind", null: false
    t.text "message", null: false
    t.datetime "sent_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ticket_id"], name: "index_notification_logs_on_ticket_id"
    t.index ["user_id", "sent_at"], name: "index_notification_logs_on_user_id_and_sent_at"
    t.index ["user_id"], name: "index_notification_logs_on_user_id"
  end

  create_table "notification_preferences", force: :cascade do |t|
    t.integer "user_id", null: false
    t.boolean "enabled", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_notification_preferences_on_user_id"
  end

  create_table "reservations", force: :cascade do |t|
    t.string "name"
    t.date "date"
    t.time "time"
    t.string "course"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "start_time"
    t.datetime "end_time"
    t.integer "user_id"
    t.integer "ticket_id"
    t.integer "status", default: 0, null: false
    t.datetime "cancelled_at"
    t.text "cancellation_reason"
    t.boolean "recurring", default: false
    t.string "recurring_type"
    t.date "recurring_until"
    t.integer "parent_reservation_id"
    t.datetime "confirmation_sent_at"
    t.datetime "reminder_sent_at"
    t.integer "individual_interval_minutes"
    t.boolean "is_break", default: false, null: false
    t.index ["individual_interval_minutes"], name: "index_reservations_on_individual_interval_minutes"
    t.index ["is_break"], name: "index_reservations_on_is_break"
    t.index ["parent_reservation_id"], name: "index_reservations_on_parent_reservation_id"
    t.index ["start_time"], name: "index_reservations_on_start_time"
    t.index ["status", "start_time"], name: "index_reservations_on_status_and_start_time"
    t.index ["status"], name: "index_reservations_on_status"
    t.index ["user_id", "start_time"], name: "index_reservations_on_user_id_and_start_time"
  end

  create_table "shifts", force: :cascade do |t|
    t.date "date"
    t.string "shift_type"
    t.time "start_time"
    t.time "end_time"
    t.text "notes"
    t.json "breaks"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ticket_templates", force: :cascade do |t|
    t.string "name"
    t.integer "total_count"
    t.integer "expiry_days"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "price"
  end

  create_table "ticket_usages", force: :cascade do |t|
    t.integer "ticket_id", null: false
    t.integer "user_id", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "note"
    t.index ["ticket_id"], name: "index_ticket_usages_on_ticket_id"
    t.index ["user_id", "used_at"], name: "index_ticket_usages_on_user_id_and_used_at"
    t.index ["user_id"], name: "index_ticket_usages_on_user_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.integer "total_count"
    t.integer "remaining_count"
    t.datetime "purchase_date"
    t.datetime "expiry_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "title"
    t.integer "ticket_template_id"
    t.index ["ticket_template_id"], name: "index_tickets_on_ticket_template_id"
    t.index ["user_id", "expiry_date"], name: "index_tickets_on_user_id_and_expiry_date"
    t.index ["user_id", "remaining_count"], name: "index_tickets_on_user_id_and_remaining_count"
    t.index ["user_id"], name: "index_tickets_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "line_user_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.text "admin_memo"
    t.string "postal_code"
    t.string "address"
    t.string "phone_number"
    t.string "email"
    t.date "birth_date"
    t.index ["line_user_id"], name: "index_users_on_line_user_id", unique: true
  end

  create_table "weekly_schedules", force: :cascade do |t|
    t.date "week_start_date", null: false
    t.json "schedule_data", default: {}, null: false
    t.boolean "is_recurring", default: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_recurring"], name: "index_weekly_schedules_on_is_recurring"
    t.index ["week_start_date"], name: "index_weekly_schedules_on_week_start_date", unique: true
  end

  add_foreign_key "notification_logs", "tickets"
  add_foreign_key "notification_logs", "users"
  add_foreign_key "notification_preferences", "users"
  add_foreign_key "ticket_usages", "tickets"
  add_foreign_key "ticket_usages", "users"
  add_foreign_key "tickets", "users"
end

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

ActiveRecord::Schema[7.2].define(version: 2025_07_05_162020) do
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
    t.date "expires_at"
    t.string "title"
    t.integer "ticket_template_id"
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
  end

  add_foreign_key "ticket_usages", "tickets"
  add_foreign_key "ticket_usages", "users"
  add_foreign_key "tickets", "users"
end

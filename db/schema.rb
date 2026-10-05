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

ActiveRecord::Schema[8.1].define(version: 2026_09_21_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "blocked_times", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.datetime "end_time", null: false
    t.string "reason", null: false
    t.bigint "staff_id"
    t.datetime "start_time", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "staff_id", "start_time"], name: "index_blocked_times_on_business_id_and_staff_id_and_start_time"
    t.index ["business_id"], name: "index_blocked_times_on_business_id"
    t.index ["staff_id"], name: "index_blocked_times_on_staff_id"
  end

  create_table "booking_items", force: :cascade do |t|
    t.bigint "booking_id", null: false
    t.datetime "created_at", null: false
    t.integer "duration_minutes", null: false
    t.tstzrange "during"
    t.integer "price", null: false
    t.bigint "service_id", null: false
    t.bigint "staff_id"
    t.datetime "updated_at", null: false
    t.index ["booking_id", "service_id"], name: "index_booking_items_on_booking_id_and_service_id"
    t.index ["booking_id"], name: "index_booking_items_on_booking_id"
    t.index ["during"], name: "index_booking_items_on_during", using: :gist
    t.index ["service_id"], name: "index_booking_items_on_service_id"
    t.index ["staff_id"], name: "index_booking_items_on_staff_id"
    t.exclusion_constraint "staff_id WITH =, during WITH &&", where: "(during IS NOT NULL) AND (staff_id IS NOT NULL)", using: :gist, name: "no_overlapping_bookings"
  end

  create_table "bookings", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.datetime "end_time", null: false
    t.string "notes"
    t.string "payment_method"
    t.string "reference", null: false
    t.datetime "start_time", null: false
    t.integer "status", default: 0, null: false
    t.bigint "total_amount", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["business_id", "status"], name: "index_bookings_on_business_id_and_status"
    t.index ["business_id"], name: "index_bookings_on_business_id"
    t.index ["reference"], name: "index_bookings_on_reference", unique: true
    t.index ["user_id", "start_time"], name: "index_bookings_on_user_id_and_start_time"
    t.index ["user_id", "status"], name: "index_bookings_on_user_id_and_status"
    t.index ["user_id"], name: "index_bookings_on_user_id"
  end

  create_table "business_categories", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "category_id"], name: "index_business_categories_on_business_id_and_category_id", unique: true
    t.index ["business_id"], name: "index_business_categories_on_business_id"
    t.index ["category_id"], name: "index_business_categories_on_category_id"
  end

  create_table "business_galleries", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.string "caption"
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["business_id"], name: "index_business_galleries_on_business_id"
  end

  create_table "business_hours", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.integer "close_minute", null: false
    t.boolean "closed", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "open_minute", null: false
    t.datetime "updated_at", null: false
    t.integer "weekday", null: false
    t.index ["business_id", "weekday"], name: "index_business_hours_on_business_id_and_weekday", unique: true
    t.index ["business_id"], name: "index_business_hours_on_business_id"
  end

  create_table "businesses", force: :cascade do |t|
    t.string "address", null: false
    t.float "avg_rating"
    t.bigint "city_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.decimal "latitude", precision: 9, scale: 6
    t.decimal "longitude", precision: 9, scale: 6
    t.string "name", null: false
    t.bigint "owner_id", null: false
    t.string "phone", null: false
    t.string "slug", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["avg_rating"], name: "index_businesses_on_avg_rating"
    t.index ["city_id"], name: "index_businesses_on_city_id"
    t.index ["owner_id"], name: "index_businesses_on_owner_id"
    t.index ["slug"], name: "index_businesses_on_slug", unique: true
    t.index ["status"], name: "index_businesses_on_status"
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "icon_name"
    t.boolean "is_popular", default: false, null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.string "tagline"
    t.datetime "updated_at", null: false
    t.index ["is_popular"], name: "index_categories_on_is_popular"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "cities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_cities_on_slug", unique: true
  end

  create_table "favorites", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["business_id"], name: "index_favorites_on_business_id"
    t.index ["user_id", "business_id"], name: "index_favorites_on_user_id_and_business_id", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "promotions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "business_id", null: false
    t.string "code"
    t.datetime "created_at", null: false
    t.string "description"
    t.integer "discount_percent"
    t.datetime "ends_at"
    t.datetime "starts_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "active"], name: "index_promotions_on_business_id_and_active"
    t.index ["business_id"], name: "index_promotions_on_business_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.integer "rating", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["business_id", "created_at"], name: "index_reviews_on_business_id_and_created_at"
    t.index ["business_id"], name: "index_reviews_on_business_id"
    t.index ["user_id", "business_id"], name: "index_reviews_on_user_id_and_business_id", unique: true
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "services", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "business_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "duration_minutes", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.integer "price", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "active"], name: "index_services_on_business_id_and_active"
    t.index ["business_id"], name: "index_services_on_business_id"
    t.index ["category_id"], name: "index_services_on_category_id"
  end

  create_table "staff_breaks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "end_minute", null: false
    t.bigint "staff_id", null: false
    t.integer "start_minute", null: false
    t.datetime "updated_at", null: false
    t.integer "weekday", null: false
    t.index ["staff_id", "weekday"], name: "index_staff_breaks_on_staff_id_and_weekday"
    t.index ["staff_id"], name: "index_staff_breaks_on_staff_id"
  end

  create_table "staff_schedules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "end_minute", null: false
    t.bigint "staff_id", null: false
    t.integer "start_minute", null: false
    t.datetime "updated_at", null: false
    t.integer "weekday", null: false
    t.index ["staff_id", "weekday", "start_minute"], name: "index_staff_schedules_on_staff_id_and_weekday_and_start_minute", unique: true
    t.index ["staff_id", "weekday"], name: "index_staff_schedules_on_staff_id_and_weekday"
    t.index ["staff_id"], name: "index_staff_schedules_on_staff_id"
  end

  create_table "staff_services", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "service_id", null: false
    t.bigint "staff_id", null: false
    t.datetime "updated_at", null: false
    t.index ["service_id"], name: "index_staff_services_on_service_id"
    t.index ["staff_id", "service_id"], name: "index_staff_services_on_staff_id_and_service_id", unique: true
    t.index ["staff_id"], name: "index_staff_services_on_staff_id"
  end

  create_table "staffs", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "avatar_color"
    t.bigint "business_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["business_id", "name"], name: "index_staffs_on_business_id_and_name"
    t.index ["business_id"], name: "index_staffs_on_business_id"
    t.index ["user_id"], name: "index_staffs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.string "name", default: "", null: false
    t.string "phone"
    t.string "provider"
    t.datetime "remember_created_at"
    t.string "remote_avatar_url"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.integer "sign_in_count", default: 0, null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "blocked_times", "businesses"
  add_foreign_key "blocked_times", "staffs"
  add_foreign_key "booking_items", "bookings"
  add_foreign_key "booking_items", "services"
  add_foreign_key "booking_items", "staffs"
  add_foreign_key "bookings", "businesses"
  add_foreign_key "bookings", "users"
  add_foreign_key "business_categories", "businesses"
  add_foreign_key "business_categories", "categories"
  add_foreign_key "business_galleries", "businesses"
  add_foreign_key "business_hours", "businesses"
  add_foreign_key "businesses", "cities"
  add_foreign_key "businesses", "users", column: "owner_id"
  add_foreign_key "favorites", "businesses"
  add_foreign_key "favorites", "users"
  add_foreign_key "promotions", "businesses"
  add_foreign_key "reviews", "businesses"
  add_foreign_key "reviews", "users"
  add_foreign_key "services", "businesses"
  add_foreign_key "services", "categories"
  add_foreign_key "staff_breaks", "staffs"
  add_foreign_key "staff_schedules", "staffs"
  add_foreign_key "staff_services", "services"
  add_foreign_key "staff_services", "staffs"
  add_foreign_key "staffs", "businesses"
  add_foreign_key "staffs", "users"
end

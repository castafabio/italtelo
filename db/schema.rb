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

ActiveRecord::Schema.define(version: 2022_06_23_093438) do

  create_table "active_storage_attachments", charset: "utf8mb3", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb3", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", charset: "utf8mb3", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "aggregated_jobs", charset: "utf8mb3", force: :cascade do |t|
    t.integer "customer_machine_id"
    t.string "code"
    t.string "status", default: "brand_new"
    t.text "notes"
    t.integer "print_number_of_files", default: 0
    t.integer "cut_number_of_files", default: 0
    t.boolean "need_printing", default: false
    t.boolean "need_cutting", default: false
    t.datetime "send_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "print_customer_machine_id"
    t.bigint "cut_customer_machine_id"
    t.index ["customer_machine_id"], name: "index_aggregated_jobs_on_customer_machine_id"
    t.index ["cut_customer_machine_id"], name: "index_aggregated_jobs_on_cut_customer_machine_id"
    t.index ["print_customer_machine_id"], name: "index_aggregated_jobs_on_print_customer_machine_id"
  end

  create_table "customer_machines", charset: "utf8mb3", force: :cascade do |t|
    t.string "name"
    t.string "kind"
    t.string "ip_address"
    t.string "serial_number"
    t.string "path"
    t.string "username"
    t.string "psw"
    t.string "hotfolder_path"
    t.text "api_key"
    t.string "import_job"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "cutters", charset: "utf8mb3", force: :cascade do |t|
    t.string "resource_type"
    t.integer "resource_id"
    t.integer "customer_machine_id"
    t.string "file_name"
    t.integer "cut_time"
    t.integer "quantity", default: 0
    t.datetime "gest_sent"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["customer_machine_id"], name: "index_cutters_on_customer_machine_id"
    t.index ["resource_type", "resource_id"], name: "index_cutters_on_resource_type_and_resource_id"
  end

  create_table "epsons", charset: "utf8mb3", force: :cascade do |t|
    t.string "PrinterName"
    t.string "DocName"
    t.datetime "PrintStartTime"
    t.datetime "PrintEndTime"
    t.integer "PageNumber"
    t.string "UserMediaName"
    t.string "SerialNumber"
    t.text "Ink"
    t.string "DbSource"
    t.string "DbTable"
    t.integer "JobId"
    t.boolean "imported", default: false
  end

  create_table "line_items", charset: "utf8mb3", force: :cascade do |t|
    t.integer "customer_machine_id"
    t.integer "aggregated_job_id"
    t.string "print_reference"
    t.string "cut_reference"
    t.string "customer"
    t.string "article_code"
    t.string "article_description"
    t.string "status", default: "brand_new"
    t.string "order_year"
    t.string "order_phase"
    t.string "order_line_item"
    t.string "order_series"
    t.string "order_type"
    t.integer "order_code"
    t.integer "quantity"
    t.integer "print_number_of_files", default: 0
    t.integer "cut_number_of_files", default: 0
    t.text "notes"
    t.datetime "send_at"
    t.bigint "print_customer_machine_id"
    t.bigint "cut_customer_machine_id"
    t.index ["aggregated_job_id"], name: "index_line_items_on_aggregated_job_id"
    t.index ["customer_machine_id"], name: "index_line_items_on_customer_machine_id"
    t.index ["cut_customer_machine_id"], name: "index_line_items_on_cut_customer_machine_id"
    t.index ["print_customer_machine_id"], name: "index_line_items_on_print_customer_machine_id"
  end

  create_table "logs", charset: "utf8mb3", force: :cascade do |t|
    t.string "kind"
    t.string "action"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "printers", charset: "utf8mb3", force: :cascade do |t|
    t.bigint "customer_machine_id"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "job_id"
    t.string "file_name"
    t.text "ink"
    t.datetime "gest_sent"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.string "print_time"
    t.string "extra_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_machine_id"], name: "index_printers_on_customer_machine_id"
    t.index ["resource_type", "resource_id"], name: "index_printers_on_resource"
  end

  create_table "roles", charset: "utf8mb3", force: :cascade do |t|
    t.string "code"
    t.string "name"
    t.integer "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "roles_users", id: false, charset: "utf8mb3", force: :cascade do |t|
    t.bigint "role_id"
    t.bigint "user_id"
    t.index ["role_id", "user_id"], name: "index_roles_users_on_role_id_and_user_id", unique: true
    t.index ["role_id"], name: "index_roles_users_on_role_id"
    t.index ["user_id"], name: "index_roles_users_on_user_id"
  end

  create_table "users", charset: "utf8mb3", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "first_name", limit: 64, default: "", null: false
    t.string "last_name", limit: 64, default: "", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "aggregated_jobs", "customer_machines", column: "cut_customer_machine_id"
  add_foreign_key "aggregated_jobs", "customer_machines", column: "print_customer_machine_id"
  add_foreign_key "line_items", "customer_machines", column: "cut_customer_machine_id"
  add_foreign_key "line_items", "customer_machines", column: "print_customer_machine_id"
end

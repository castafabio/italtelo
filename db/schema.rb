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

ActiveRecord::Schema.define(version: 2022_06_20_140223) do

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
    t.integer "submit_point_id"
    t.string "status", default: "brand_new"
    t.date "deadline"
    t.datetime "switch_sent"
    t.text "error_message"
    t.text "notes"
    t.integer "print_number_of_files", default: 0
    t.integer "cut_number_of_files", default: 0
    t.boolean "need_printing", default: false
    t.boolean "need_cutting", default: false
    t.boolean "tilia", default: false
    t.boolean "aluan", default: true
    t.boolean "sending", default: false
    t.json "fields_data"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "print_customer_machine_id"
    t.bigint "cut_customer_machine_id"
    t.bigint "vg7_print_machine_id"
    t.bigint "vg7_cut_machine_id"
    t.text "code"
    t.index ["customer_machine_id"], name: "index_aggregated_jobs_on_customer_machine_id"
    t.index ["cut_customer_machine_id"], name: "index_aggregated_jobs_on_cut_customer_machine_id"
    t.index ["print_customer_machine_id"], name: "index_aggregated_jobs_on_print_customer_machine_id"
    t.index ["submit_point_id"], name: "index_aggregated_jobs_on_submit_point_id"
    t.index ["vg7_cut_machine_id"], name: "index_aggregated_jobs_on_vg7_cut_machine_id"
    t.index ["vg7_print_machine_id"], name: "index_aggregated_jobs_on_vg7_print_machine_id"
  end

  create_table "customer_machines", charset: "utf8mb3", force: :cascade do |t|
    t.string "name"
    t.string "machine_switch_name"
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
    t.text "vg7_machine_reference"
  end

  create_table "customer_machines_vg7_machines", id: false, charset: "utf8mb3", force: :cascade do |t|
    t.bigint "customer_machine_id", null: false
    t.bigint "vg7_machine_id", null: false
  end

  create_table "customizations", charset: "utf8mb3", force: :cascade do |t|
    t.string "parameter"
    t.string "value"
    t.string "um"
    t.text "notes"
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

  create_table "line_items", charset: "utf8mb3", force: :cascade do |t|
    t.integer "order_id"
    t.integer "customer_machine_id"
    t.integer "aggregated_job_id"
    t.integer "submit_point_id"
    t.integer "row_number"
    t.integer "subjects"
    t.integer "quantity"
    t.integer "height"
    t.integer "width"
    t.integer "print_number_of_files", default: 0
    t.integer "cut_number_of_files", default: 0
    t.string "material"
    t.string "article_code"
    t.string "article_name"
    t.string "scale", default: "1:1"
    t.string "sides", default: "Monofacciale"
    t.text "description"
    t.text "error_message"
    t.datetime "switch_sent"
    t.boolean "aluan", default: true
    t.boolean "need_printing", default: false
    t.boolean "need_cutting", default: false
    t.boolean "sending", default: false
    t.json "fields_data"
    t.bigint "print_customer_machine_id"
    t.bigint "cut_customer_machine_id"
    t.bigint "vg7_print_machine_id"
    t.bigint "vg7_cut_machine_id"
    t.index ["aggregated_job_id"], name: "index_line_items_on_aggregated_job_id"
    t.index ["customer_machine_id"], name: "index_line_items_on_customer_machine_id"
    t.index ["cut_customer_machine_id"], name: "index_line_items_on_cut_customer_machine_id"
    t.index ["order_id"], name: "index_line_items_on_order_id"
    t.index ["print_customer_machine_id"], name: "index_line_items_on_print_customer_machine_id"
    t.index ["submit_point_id"], name: "index_line_items_on_submit_point_id"
    t.index ["vg7_cut_machine_id"], name: "index_line_items_on_vg7_cut_machine_id"
    t.index ["vg7_print_machine_id"], name: "index_line_items_on_vg7_print_machine_id"
  end

  create_table "logs", charset: "utf8mb3", force: :cascade do |t|
    t.string "kind"
    t.string "action"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "orders", charset: "utf8mb3", force: :cascade do |t|
    t.string "order_code"
    t.date "order_date"
    t.string "customer"
  end

  create_table "printers", charset: "utf8mb3", force: :cascade do |t|
    t.bigint "customer_machine_id"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "job_id"
    t.string "file_name"
    t.integer "copies", default: 0
    t.string "material", default: ""
    t.text "ink"
    t.datetime "gest_sent"
    t.datetime "start_at"
    t.string "print_time"
    t.string "folder"
    t.string "extra_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_machine_id"], name: "index_printers_on_customer_machine_id"
    t.index ["folder"], name: "index_printers_on_folder"
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

  create_table "submit_points", charset: "utf8mb3", force: :cascade do |t|
    t.string "name"
    t.string "kind", default: "preflight"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "switch_fields", charset: "utf8mb3", force: :cascade do |t|
    t.integer "submit_point_id"
    t.string "dependency", default: ""
    t.string "dependency_condition", default: ""
    t.string "dependency_value", default: ""
    t.boolean "display_field", default: false
    t.boolean "read_only", default: false
    t.string "field_id"
    t.string "kind"
    t.text "enum_values"
    t.boolean "required"
    t.string "name", default: ""
    t.text "description"
    t.integer "sort"
    t.string "default_value"
    t.boolean "visible_on_line_item", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["submit_point_id"], name: "index_switch_fields_on_submit_point_id"
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

  create_table "vg7_machines", charset: "utf8mb3", force: :cascade do |t|
    t.text "description"
    t.text "vg7_machine_reference"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "aggregated_jobs", "customer_machines", column: "cut_customer_machine_id"
  add_foreign_key "aggregated_jobs", "customer_machines", column: "print_customer_machine_id"
  add_foreign_key "aggregated_jobs", "vg7_machines", column: "vg7_cut_machine_id"
  add_foreign_key "aggregated_jobs", "vg7_machines", column: "vg7_print_machine_id"
  add_foreign_key "line_items", "customer_machines", column: "cut_customer_machine_id"
  add_foreign_key "line_items", "customer_machines", column: "print_customer_machine_id"
  add_foreign_key "line_items", "vg7_machines", column: "vg7_cut_machine_id"
  add_foreign_key "line_items", "vg7_machines", column: "vg7_print_machine_id"
end

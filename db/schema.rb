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

ActiveRecord::Schema[8.0].define(version: 2025_08_23_083033) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "message_type"
    t.text "content"
    t.text "user_prompt"
    t.text "ai_response"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_chat_messages_on_conversation_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title"
    t.string "session_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_conversations_on_user_id"
  end

  create_table "course_modules", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.string "title"
    t.integer "duration_hours"
    t.text "description"
    t.integer "order_position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "detailed_description"
    t.boolean "content_generated"
    t.index ["course_id"], name: "index_course_modules_on_course_id"
  end

  create_table "course_steps", force: :cascade do |t|
    t.bigint "course_module_id", null: false
    t.string "title"
    t.text "content"
    t.string "step_type"
    t.integer "duration_minutes"
    t.integer "order_position"
    t.text "resources"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "detailed_content"
    t.boolean "content_generated"
    t.index ["course_module_id"], name: "index_course_steps_on_course_module_id"
  end

  create_table "courses", force: :cascade do |t|
    t.string "title"
    t.text "prompt"
    t.json "task_list"
    t.json "structure"
    t.bigint "admin_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "conversation_id", null: false
    t.boolean "full_content_generated"
    t.datetime "full_content_generated_at"
    t.index ["admin_id"], name: "index_courses_on_admin_id"
    t.index ["conversation_id"], name: "index_courses_on_conversation_id"
  end

  create_table "document_chunks", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.text "content"
    t.integer "chunk_order"
    t.vector "embedding", limit: 1536
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_document_chunks_on_document_id"
    t.index ["embedding"], name: "index_document_chunks_on_embedding", opclass: :vector_cosine_ops, using: :ivfflat
  end

  create_table "documents", force: :cascade do |t|
    t.string "title"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_documents_on_user_id"
  end

  create_table "progresses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "course_id", null: false
    t.integer "completed_steps"
    t.json "quiz_scores"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_progresses_on_course_id"
    t.index ["user_id"], name: "index_progresses_on_user_id"
  end

  create_table "steps", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.integer "order"
    t.text "content"
    t.json "quiz_questions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_steps_on_course_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "role"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chat_messages", "conversations"
  add_foreign_key "conversations", "users"
  add_foreign_key "course_modules", "courses"
  add_foreign_key "course_steps", "course_modules"
  add_foreign_key "courses", "conversations"
  add_foreign_key "courses", "users", column: "admin_id"
  add_foreign_key "document_chunks", "documents"
  add_foreign_key "documents", "users"
  add_foreign_key "progresses", "courses"
  add_foreign_key "progresses", "users"
  add_foreign_key "steps", "courses"
end

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

ActiveRecord::Schema[8.1].define(version: 2026_05_27_132916) do
  create_table "agent_messages", force: :cascade do |t|
    t.integer "agent_session_id", null: false
    t.text "content"
    t.decimal "cost_in_cents", precision: 10, scale: 6, default: "0.0"
    t.datetime "created_at", null: false
    t.json "metadata", default: {}
    t.integer "processing_time_ms"
    t.string "role", null: false
    t.integer "tokens_used"
    t.json "tool_arguments"
    t.string "tool_name"
    t.json "tool_result"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["agent_session_id", "created_at"], name: "index_agent_messages_on_agent_session_id_and_created_at"
    t.index ["agent_session_id"], name: "index_agent_messages_on_agent_session_id"
    t.index ["user_id", "role"], name: "index_agent_messages_on_user_id_and_role"
    t.index ["user_id"], name: "index_agent_messages_on_user_id"
  end

  create_table "agent_sessions", force: :cascade do |t|
    t.json "context", default: {}
    t.string "conversation_title"
    t.datetime "created_at", null: false
    t.string "job_id"
    t.datetime "last_activity_at"
    t.datetime "locked_at"
    t.string "locked_by"
    t.json "messages_log", default: []
    t.integer "schema_version", default: 1
    t.string "session_token", null: false
    t.string "status", default: "idle", null: false
    t.integer "token_count", default: 0
    t.integer "tool_calls_count", default: 0
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["session_token"], name: "index_agent_sessions_on_session_token", unique: true
    t.index ["status", "locked_at"], name: "idx_agent_sessions_status_locked"
    t.index ["user_id", "last_activity_at"], name: "index_agent_sessions_on_user_id_and_last_activity_at"
    t.index ["user_id", "status"], name: "index_agent_sessions_on_user_id_and_status"
    t.index ["user_id"], name: "index_agent_sessions_on_user_id"
  end

  create_table "agent_tools", force: :cascade do |t|
    t.integer "cooldown_seconds"
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "is_active"
    t.string "name"
    t.json "parameters_schema"
    t.string "ruby_class_path"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_agent_tools_on_name", unique: true
  end

  create_table "financial_goals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.json "plan"
    t.integer "priority"
    t.text "reasoning"
    t.string "status", default: "planned"
    t.decimal "target_amount"
    t.date "target_date"
    t.datetime "updated_at", null: false
    t.integer "user_id"
  end

  create_table "investment_simulations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "projection_yearly"
    t.date "simulated_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_investment_simulations_on_user_id"
  end

  create_table "milestones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "current_amount"
    t.json "details"
    t.integer "financial_goal_id", null: false
    t.integer "order_number"
    t.string "phase"
    t.string "status"
    t.decimal "target_amount"
    t.datetime "updated_at", null: false
    t.index ["financial_goal_id"], name: "index_milestones_on_financial_goal_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.string "amount"
    t.string "category"
    t.datetime "created_at", null: false
    t.date "date"
    t.string "description"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.date "birth_date"
    t.datetime "created_at", null: false
    t.decimal "current_savings"
    t.string "email"
    t.string "encrypted_password"
    t.decimal "monthly_income"
    t.string "name"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "agent_messages", "agent_sessions"
  add_foreign_key "agent_messages", "users"
  add_foreign_key "agent_sessions", "users"
  add_foreign_key "financial_goals", "users"
  add_foreign_key "investment_simulations", "users"
  add_foreign_key "milestones", "financial_goals"
  add_foreign_key "transactions", "users"
end

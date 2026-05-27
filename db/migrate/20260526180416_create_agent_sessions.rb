class CreateAgentSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: 'idle'
      t.string :conversation_title
      t.string :session_token, null: false
      t.json :context, default: {}
      t.json :messages_log, default: []
      t.integer :token_count, default: 0
      t.integer :tool_calls_count, default: 0
      t.datetime :last_activity_at
      t.string :job_id
      t.datetime :locked_at
      t.string :locked_by
      t.integer :schema_version, default: 1
      t.timestamps
    end
    
    add_index :agent_sessions, :session_token, unique: true
    add_index :agent_sessions, [:user_id, :status]
    add_index :agent_sessions, [:user_id, :last_activity_at]
    add_index :agent_sessions, [:status, :locked_at], name: 'idx_agent_sessions_status_locked'
  end
end

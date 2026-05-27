class CreateAgentMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_messages do |t|
      t.references :agent_session, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content
      t.json :metadata, default: {}      # ← json
      t.string :tool_name
      t.json :tool_arguments              # ← json
      t.json :tool_result                 # ← json
      t.integer :tokens_used
      t.decimal :cost_in_cents, precision: 10, scale: 6, default: 0
      t.integer :processing_time_ms
      t.timestamps
    end
    
    add_index :agent_messages, [:agent_session_id, :created_at]
    add_index :agent_messages, [:user_id, :role]
  end
end

class CreateAgentTools < ActiveRecord::Migration[8.1]
  def change
    create_table :agent_tools do |t|
      t.string :name
      t.text :description
      t.json :parameters_schema
      t.string :ruby_class_path
      t.boolean :is_active
      t.integer :cooldown_seconds

      t.timestamps
    end
    add_index :agent_tools, :name, unique: true
  end
end

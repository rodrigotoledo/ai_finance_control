class CreateMilestones < ActiveRecord::Migration[8.1]
  def change
    create_table :milestones do |t|
      t.references :financial_goal, null: false, foreign_key: true
      t.string :phase
      t.decimal :target_amount
      t.decimal :current_amount
      t.string :status
      t.integer :order_number

      t.timestamps
    end
  end
end

class CreateFinancialGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :financial_goals do |t|
      t.string :name
      t.decimal :target_amount
      t.date :target_date
      t.integer :priority

      t.timestamps
    end
  end
end

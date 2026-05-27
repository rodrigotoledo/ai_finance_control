class EnhanceFinancialGoals < ActiveRecord::Migration[8.1]
  def change
    add_reference :financial_goals, :user, foreign_key: true
    add_column :financial_goals, :status, :string, default: "planned"
    add_column :financial_goals, :plan, :json
    add_column :financial_goals, :reasoning, :text
  end
end

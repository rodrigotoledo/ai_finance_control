class FixFinancialGoalsForeignKey < ActiveRecord::Migration[8.1]
  def change
    add_column :financial_goals, :user_id, :integer unless column_exists?(:financial_goals, :user_id)
    add_foreign_key :financial_goals, :users, if_not_exists: true
    add_column :financial_goals, :status, :string, default: "planned" unless column_exists?(:financial_goals, :status)
    add_column :financial_goals, :plan, :json unless column_exists?(:financial_goals, :plan)
    add_column :financial_goals, :reasoning, :text unless column_exists?(:financial_goals, :reasoning)
  end
end

class AddFinancialFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :current_savings, :decimal
  end
end

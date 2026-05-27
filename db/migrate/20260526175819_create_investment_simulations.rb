class CreateInvestmentSimulations < ActiveRecord::Migration[8.1]
  def change
    create_table :investment_simulations do |t|
      t.references :user, null: false, foreign_key: true
      t.date :simulated_at
      t.json :projection_yearly

      t.timestamps
    end
  end
end

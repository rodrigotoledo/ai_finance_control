class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.string :amount
      t.string :category
      t.date :date
      t.string :description

      t.timestamps
    end
  end
end

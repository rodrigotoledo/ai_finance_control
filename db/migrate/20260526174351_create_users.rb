class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.decimal :monthly_income
      t.date :birth_date

      t.timestamps
    end
  end
end

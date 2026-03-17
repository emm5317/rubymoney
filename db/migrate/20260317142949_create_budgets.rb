class CreateBudgets < ActiveRecord::Migration[7.2]
  def change
    create_table :budgets do |t|
      t.references :category, null: false, foreign_key: true
      t.integer :month, null: false
      t.integer :year, null: false
      t.bigint :amount_cents, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :budgets, [:category_id, :month, :year], unique: true
  end
end

class CreateAccountBalances < ActiveRecord::Migration[7.2]
  def change
    create_table :account_balances do |t|
      t.references :account, null: false, foreign_key: true
      t.date :date, null: false
      t.bigint :balance_cents, null: false, default: 0
      t.integer :source, null: false, default: 0

      t.timestamps
    end

    add_index :account_balances, [:account_id, :date], unique: true
  end
end

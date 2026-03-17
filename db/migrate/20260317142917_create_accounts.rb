class CreateAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :account_type, null: false, default: 0
      t.string :institution
      t.string :currency, null: false, default: "USD"
      t.integer :source_type, null: false, default: 0
      t.string :plaid_account_id
      t.bigint :current_balance_cents, default: 0
      t.datetime :last_imported_at

      t.timestamps
    end

    add_index :accounts, [:user_id, :name], unique: true
  end
end

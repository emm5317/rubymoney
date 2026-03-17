class CreateTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :import, null: true, foreign_key: true
      t.references :category, null: true, foreign_key: true
      t.bigint :transfer_pair_id
      t.bigint :merchant_id
      t.date :date, null: false
      t.date :posted_date
      t.string :description, null: false
      t.string :normalized_desc
      t.bigint :amount_cents, null: false
      t.integer :transaction_type, null: false, default: 0
      t.boolean :is_transfer, null: false, default: false
      t.integer :status, null: false, default: 0
      t.text :memo
      t.string :source_type, null: false, default: "manual"
      t.string :source_fingerprint
      t.boolean :auto_categorized, null: false, default: false

      t.timestamps
    end

    add_index :transactions, [:account_id, :source_fingerprint], unique: true, where: "source_fingerprint IS NOT NULL", name: "idx_transactions_on_account_fingerprint"
    add_index :transactions, [:account_id, :date]
    add_index :transactions, :normalized_desc
    add_index :transactions, :transfer_pair_id
    add_index :transactions, :merchant_id
  end
end

class CreateTransactionTags < ActiveRecord::Migration[7.2]
  def change
    create_table :transaction_tags do |t|
      t.bigint :transaction_id, null: false
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end

    add_foreign_key :transaction_tags, :transactions
    add_index :transaction_tags, :transaction_id
    add_index :transaction_tags, [:transaction_id, :tag_id], unique: true
  end
end

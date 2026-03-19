class CreateRecurringTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :recurring_transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :category, foreign_key: true
      t.string     :title, null: false
      t.string     :description_pattern, null: false
      t.bigint     :average_amount_cents, null: false
      t.bigint     :last_amount_cents
      t.integer    :frequency, null: false, default: 0
      t.float      :confidence, default: 0.0
      t.integer    :occurrence_count, default: 0
      t.date       :last_seen_date
      t.date       :next_expected_date
      t.integer    :status, null: false, default: 0
      t.boolean    :user_confirmed, default: false
      t.boolean    :user_dismissed, default: false
      t.float      :amount_variance, default: 0.0
      t.integer    :average_interval_days
      t.timestamps
    end

    add_index :recurring_transactions, [:account_id, :description_pattern],
              unique: true, name: "idx_recurring_on_account_desc_pattern"
    add_index :recurring_transactions, :status
    add_index :recurring_transactions, :next_expected_date
  end
end

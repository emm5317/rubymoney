class AddIsRecurringToTransactions < ActiveRecord::Migration[7.2]
  def change
    add_column :transactions, :is_recurring, :boolean, default: false, null: false
  end
end

class TransactionTag < ApplicationRecord
  # Use custom foreign key name to avoid conflict with AR's #transaction method
  belongs_to :financial_transaction, class_name: "Transaction", foreign_key: :transaction_id
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :transaction_id }
end

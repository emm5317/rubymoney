class Tag < ApplicationRecord
  has_many :transaction_tags, dependent: :destroy
  has_many :transactions, through: :transaction_tags, source: :financial_transaction

  validates :name, presence: true, uniqueness: true

  scope :sorted, -> { order(:name) }
end

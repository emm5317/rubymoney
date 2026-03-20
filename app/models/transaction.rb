class Transaction < ApplicationRecord
  include PgSearch::Model

  pg_search_scope :search_by_description, against: [:description, :normalized_desc, :memo],
    using: { tsearch: { prefix: true } }

  belongs_to :account
  belongs_to :import, optional: true
  belongs_to :category, optional: true
  belongs_to :transfer_pair, class_name: "Transaction", optional: true

  has_many :transaction_tags, dependent: :destroy
  has_many :tags, through: :transaction_tags, source: :tag

  enum :transaction_type, { debit: 0, credit: 1 }
  enum :status, { pending: 0, cleared: 1, reconciled: 2 }

  validates :date, presence: true
  validates :description, presence: true
  validates :amount_cents, presence: true, numericality: { other_than: 0 }

  before_save :set_normalized_desc, if: :description_changed?

  scope :uncategorized, -> { where(category_id: nil) }
  scope :categorized, -> { where.not(category_id: nil) }
  scope :non_transfer, -> { where(is_transfer: false) }
  scope :transfers_only, -> { where(is_transfer: true) }
  scope :for_month, ->(date) { where(date: date.beginning_of_month..date.end_of_month) }
  scope :for_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }
  scope :by_account, ->(account_id) { where(account_id: account_id) }
  scope :debits, -> { where(transaction_type: :debit) }
  scope :credits, -> { where(transaction_type: :credit) }
  scope :tagged_with, ->(tag) { joins(:tags).where(tags: { id: tag }) }
  scope :recent, -> { order(date: :desc) }

  def amount
    amount_cents&./(100.0)
  end

  def amount=(val)
    self.amount_cents = (val.to_f * 100).round
  end

  def formatted_amount
    "$#{'%.2f' % amount.abs}"
  end

  private

  def set_normalized_desc
    self.normalized_desc = description
      .gsub(/\d{4}\*+\d{4}/, "")  # Strip card number patterns first
      .gsub(/\s+/, " ")            # Then collapse whitespace
      .strip
  end
end

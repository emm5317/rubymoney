class Rule < ApplicationRecord
  belongs_to :category

  enum :match_field, { description: 0, normalized_desc: 1, amount_field: 2 }
  enum :match_type, { contains: 0, exact: 1, starts_with: 2, regex: 3, gt: 4, lt: 5, between: 6 }

  validates :match_value, presence: true
  validates :priority, numericality: { only_integer: true }

  scope :enabled, -> { where(enabled: true) }
  scope :by_priority, -> { order(priority: :desc) }

  def matches?(txn)
    if amount_field?
      return false if txn.amount_cents.blank?

      case match_type
      when "gt"
        txn.amount_cents > match_value.to_i
      when "lt"
        txn.amount_cents < match_value.to_i
      when "between"
        txn.amount_cents.between?(match_value.to_i, match_value_upper.to_i)
      else
        false
      end
    else
      field_value = txn.send(match_field)
      return false if field_value.blank?

      case match_type
      when "contains"
        field_value.downcase.include?(match_value.downcase)
      when "exact"
        field_value.downcase == match_value.downcase
      when "starts_with"
        field_value.downcase.start_with?(match_value.downcase)
      when "regex"
        field_value.match?(Regexp.new(match_value, Regexp::IGNORECASE))
      else
        false
      end
    end
  end
end

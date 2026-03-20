class Rule < ApplicationRecord
  TEXT_MATCH_TYPES = %w[contains exact starts_with regex].freeze
  NUMERIC_MATCH_TYPES = %w[gt lt between].freeze

  belongs_to :category

  enum :match_field, { description: 0, normalized_desc: 1, amount_field: 2 }
  enum :match_type, { contains: 0, exact: 1, starts_with: 2, regex: 3, gt: 4, lt: 5, between: 6 }

  validates :match_value, presence: true
  validates :priority, numericality: { only_integer: true }
  validate :match_type_supported_for_field
  validate :regex_pattern_must_compile, if: :regex?

  scope :enabled, -> { where(enabled: true) }
  scope :by_priority, -> { order(priority: :desc) }

  def text_match_type?
    TEXT_MATCH_TYPES.include?(match_type.to_s)
  end

  def numeric_match_type?
    NUMERIC_MATCH_TYPES.include?(match_type.to_s)
  end

  def preview_error_message
    if amount_field? && text_match_type?
      "Amount rules only support Greater Than, Less Than, or Between."
    elsif !amount_field? && numeric_match_type?
      "Description rules only support Contains, Exact, Starts With, or Regex."
    end
  end

  def regex_error_message
    return if !regex? || match_value.blank?

    Regexp.new(match_value, Regexp::IGNORECASE)
    nil
  rescue RegexpError => e
    "Match value is not a valid regex: #{e.message}"
  end

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

  private

  def match_type_supported_for_field
    return if preview_error_message.blank?

    errors.add(:match_type, preview_error_message)
  end

  def regex_pattern_must_compile
    return if regex_error_message.blank?

    errors.add(:match_value, regex_error_message.delete_prefix("Match value "))
  end
end

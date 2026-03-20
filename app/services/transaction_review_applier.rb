class TransactionReviewApplier
  def initialize(user:, entries:)
    @user = user
    @entries = entries
  end

  def call
    suggestions = TransactionReviewService.new(user: @user).suggestions_by_signature
    next_priority = Rule.maximum(:priority).to_i + 10

    result = {
      groups_updated: 0,
      transactions_categorized: 0,
      rules_created: 0
    }

    @entries.each do |entry|
      next unless truthy?(entry[:apply])

      category_id = entry[:category_id].presence
      next unless category_id

      suggestion = suggestions[entry[:signature].to_s]
      next unless suggestion

      updated = Transaction.where(id: suggestion.transaction_ids, category_id: nil)
        .update_all(category_id: category_id, auto_categorized: false, updated_at: Time.current)

      if truthy?(entry[:create_rule]) && entry[:rule_pattern].present?
        unless Rule.exists?(
          category_id: category_id,
          match_field: Rule.match_fields[:normalized_desc],
          match_type: Rule.match_types[:contains],
          match_value: entry[:rule_pattern]
        )
          Rule.create!(
            category_id: category_id,
            match_field: :normalized_desc,
            match_type: :contains,
            match_value: entry[:rule_pattern],
            priority: next_priority,
            enabled: true
          )
          next_priority += 10
          result[:rules_created] += 1
        end
      end

      next if updated.zero?

      result[:groups_updated] += 1
      result[:transactions_categorized] += updated
    end

    result
  end

  private

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end

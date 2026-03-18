class Categorizer
  # Categorize a single transaction using enabled rules in priority order.
  # Returns the matched Rule, or nil if no rules matched.
  def categorize(transaction)
    return nil if transaction.category_id.present?

    matched_rule = find_matching_rule(transaction)
    return nil unless matched_rule

    transaction.update!(
      category_id: matched_rule.category_id,
      auto_categorized: true
    )
    matched_rule
  end

  # Categorize multiple transactions. Returns count of categorized transactions.
  def categorize_batch(transactions)
    rules = Rule.enabled.by_priority.includes(:category).to_a
    return 0 if rules.empty?

    count = 0
    transactions.each do |txn|
      next if txn.category_id.present?

      matched = rules.find { |rule| rule.matches?(txn) }
      next unless matched

      txn.update!(category_id: matched.category_id, auto_categorized: true)
      count += 1
    end
    count
  end

  # Apply rules retroactively to all uncategorized transactions
  def apply_retroactive
    transactions = Transaction.uncategorized.to_a
    categorize_batch(transactions)
  end

  private

  def find_matching_rule(transaction)
    Rule.enabled.by_priority.find { |rule| rule.matches?(transaction) }
  end
end

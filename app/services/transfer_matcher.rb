class TransferMatcher
  DATE_WINDOW = 3 # days

  # Find potential transfer matches for a transaction.
  # Returns transactions from different accounts with the same absolute amount
  # but opposite sign, within DATE_WINDOW days.
  def find_candidates(transaction, user:)
    return [] if transaction.is_transfer?

    target_amount = -transaction.amount_cents

    Transaction.joins(:account)
      .where(accounts: { user_id: user.id })
      .where.not(account_id: transaction.account_id)
      .where(amount_cents: target_amount)
      .where(is_transfer: false)
      .where(transfer_pair_id: nil)
      .where(date: (transaction.date - DATE_WINDOW.days)..(transaction.date + DATE_WINDOW.days))
      .includes(:account)
      .order(Arel.sql("ABS(date - '#{transaction.date}'::date)"))
      .limit(10)
  end

  # Auto-detect and link transfers among newly imported transactions.
  # Only links unambiguous matches (exactly one candidate found).
  def detect_transfers(transactions, user:)
    linked = 0
    transactions.reject(&:is_transfer?).each do |txn|
      candidates = find_candidates(txn, user: user)
      next unless candidates.size == 1

      link!(txn, candidates.first)
      linked += 1
    end
    linked
  end

  # Link two transactions as a transfer pair.
  def link!(transaction_a, transaction_b)
    Transaction.transaction do
      transaction_a.update!(transfer_pair_id: transaction_b.id, is_transfer: true)
      transaction_b.update!(transfer_pair_id: transaction_a.id, is_transfer: true)
    end
  end

  # Unlink a transfer pair.
  def unlink!(transaction)
    pair = transaction.transfer_pair
    return unless pair

    Transaction.transaction do
      transaction.update!(transfer_pair_id: nil, is_transfer: false)
      pair.update!(transfer_pair_id: nil, is_transfer: false)
    end
  end
end

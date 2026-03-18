require "ofx"

module Importers
  class OfxAdapter < BaseAdapter
    def parse
      ofx = OFX(StringIO.new(file_content))
      return [] unless ofx.account&.transactions&.any?

      ofx.account.transactions.filter_map { |txn| parse_transaction(txn) }
    end

    private

    def parse_transaction(txn)
      date = txn.posted_at&.to_date
      return nil if date.nil?

      description = (txn.name.presence || txn.memo.presence || "").strip
      return nil if description.blank?

      if import_profile
        description = import_profile.apply_description_correction(description)
      end

      amount_cents = (txn.amount * 100).round
      return nil if amount_cents == 0

      {
        date: date,
        posted_date: date,
        description: description,
        amount_cents: amount_cents,
        transaction_type: determine_type(amount_cents),
        memo: txn.memo.presence,
        source_fingerprint: txn.fit_id.presence || generate_fingerprint(date: date, description: description, amount_cents: amount_cents)
      }
    end
  end
end

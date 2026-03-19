class ImportProcessor
  attr_reader :import, :account

  def initialize(import)
    @import = import
    @account = import.account
  end

  # Phase 1: Parse file and store preview data without committing transactions
  def preview
    parsed = parse_file
    import.update!(
      status: :previewing,
      preview_data: parsed.first(500), # Cap preview at 500 rows
      total_rows: parsed.size
    )
    parsed
  end

  # Phase 2: Commit previewed transactions to the database
  def confirm
    import.update!(status: :processing, started_at: Time.current)

    parsed = import.preview_data
    if parsed.blank?
      import.update!(status: :failed, error_log: [{ error: "No preview data to import", at: Time.current.iso8601 }])
      return
    end

    imported = 0
    skipped = 0
    errors = []

    # Batch-load existing fingerprints to avoid N+1 queries
    fingerprints = parsed.filter_map { |r| r.symbolize_keys[:source_fingerprint].presence || r["source_fingerprint"].presence }
    @existing_fingerprints = Transaction.where(account_id: account.id, source_fingerprint: fingerprints)
                                        .pluck(:source_fingerprint)
                                        .to_set

    parsed.each do |row_data|
      row = row_data.symbolize_keys
      result = import_row(row)
      case result
      when :imported then imported += 1
      when :skipped  then skipped += 1
      when String    then errors << { row: row, error: result, at: Time.current.iso8601 }
      end
    end

    # Auto-categorize newly imported transactions
    categorized = Categorizer.new.categorize_batch(import.transactions.uncategorized)

    # Auto-detect and link unambiguous transfer pairs
    transfers_linked = TransferMatcher.new.detect_transfers(import.transactions.reload, user: account.user)

    import.update!(
      status: :completed,
      imported_count: imported,
      skipped_count: skipped,
      error_count: errors.size,
      error_log: errors,
      completed_at: Time.current
    )

    # Update account's last_imported_at
    account.update!(last_imported_at: Time.current)

    # Learn column mapping from this import if CSV
    learn_profile if import.csv?

    { imported: imported, skipped: skipped, errors: errors.size, categorized: categorized, transfers_linked: transfers_linked }
  end

  private

  def parse_file
    content = read_file_content
    adapter = build_adapter(content)
    adapter.parse
  end

  def read_file_content
    if import.file.attached?
      import.file.download
    else
      raise "No file attached to import ##{import.id}"
    end
  end

  ADAPTER_MAP = {
    "csv" => Importers::CsvAdapter,
    "ofx" => Importers::OfxAdapter,
    "qfx" => Importers::OfxAdapter
  }.freeze

  def build_adapter(content)
    profile = ImportProfile.find_by(account_id: account.id, institution: account.institution)
    adapter_class = ADAPTER_MAP[import.file_type] || raise("Unsupported file type: #{import.file_type}")
    adapter_class.new(content, account: account, import_profile: profile)
  end

  def import_row(row)
    # Check for duplicate via preloaded fingerprints
    if row[:source_fingerprint].present? && @existing_fingerprints.include?(row[:source_fingerprint])
      return :skipped
    end

    transaction = import.transactions.build(
      account: account,
      date: row[:date],
      posted_date: row[:posted_date],
      description: row[:description],
      amount_cents: row[:amount_cents],
      transaction_type: row[:transaction_type],
      memo: row[:memo],
      source_type: import.file_type,
      source_fingerprint: row[:source_fingerprint],
      status: :cleared
    )

    if transaction.save
      :imported
    else
      transaction.errors.full_messages.join(", ")
    end
  rescue ActiveRecord::RecordNotUnique
    # Fingerprint uniqueness constraint caught a duplicate
    :skipped
  end

  def learn_profile
    profile = ImportProfile.find_or_create_by!(
      account_id: account.id,
      institution: account.institution.presence || "Unknown"
    )
    # Future: save inferred column mapping and date format
    profile
  end
end

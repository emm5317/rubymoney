require "csv"

module Importers
  class CsvAdapter < BaseAdapter
    # Default column mappings — keys are canonical fields, values are possible CSV header names
    HEADER_ALIASES = {
      date: %w[date transaction_date trans_date posting_date],
      description: %w[description desc memo narrative payee details],
      amount: %w[amount total],
      debit: %w[debit withdrawal],
      credit: %w[credit deposit],
      posted_date: %w[posted_date post_date],
      memo: %w[memo notes reference check_number]
    }.freeze

    def parse
      headers, rows = extract_headers_and_rows
      return [] if headers.blank? || rows.empty?

      mapping = resolve_column_mapping(headers)
      return [] if mapping[:date].nil? || mapping[:description].nil?

      rows.filter_map { |row| parse_row(row, mapping) }
    end

    private

    def extract_headers_and_rows
      raw_rows = CSV.parse(file_content, headers: false, liberal_parsing: true, skip_blanks: true)
      return [nil, []] if raw_rows.empty?

      header_index = raw_rows.find_index { |row| header_row?(row) } || 0
      headers = raw_rows[header_index]
      return [headers, []] if headers.blank?

      rows = raw_rows.drop(header_index + 1).map do |row|
        CSV::Row.new(headers, row)
      end

      [headers, rows]
    end

    def header_row?(row)
      headers = row.map { |value| normalize_header(value) }
      return false unless headers.include?("date") && headers.include?("description")

      headers.any? { |header| %w[amount total debit withdrawal credit deposit].include?(header) }
    end

    def resolve_column_mapping(headers)
      # Use saved profile mapping if available
      if import_profile&.column_mapping.present?
        return import_profile.column_mapping.symbolize_keys
      end

      normalized_headers = headers.map { |h| normalize_header(h) }
      mapping = {}

      HEADER_ALIASES.each do |field, aliases|
        idx = normalized_headers.index { |h| aliases.include?(h) }
        mapping[field] = headers[idx] if idx
      end

      # If no separate debit/credit and no amount column, can't parse
      if mapping[:amount].nil? && mapping[:debit].nil? && mapping[:credit].nil?
        # Try first numeric-looking column as amount
        headers.each do |h|
          next if h == mapping[:date] || h == mapping[:description]
          mapping[:amount] = h
          break
        end
      end

      mapping
    end

    def normalize_header(value)
      value&.strip&.downcase&.gsub(/[\s\-]/, "_")&.gsub(/[^\w]/, "")
    end

    def parse_row(row, mapping)
      date = parse_date(row[mapping[:date]].to_s)
      return nil if date.nil?

      description = row[mapping[:description]].to_s.strip
      return nil if description.blank?

      description = correct_description(description)

      amount_cents = extract_amount_cents(row, mapping)
      return nil if amount_cents.nil? || amount_cents == 0

      memo = row[mapping[:memo]]&.strip.presence
      posted_date = mapping[:posted_date] ? parse_date(row[mapping[:posted_date]].to_s) : nil

      {
        date: date,
        posted_date: posted_date,
        description: description,
        amount_cents: amount_cents,
        transaction_type: determine_type(amount_cents),
        memo: memo,
        source_fingerprint: generate_fingerprint(date: date, description: description, amount_cents: amount_cents)
      }
    end

    def extract_amount_cents(row, mapping)
      if mapping[:amount]
        parse_amount(row[mapping[:amount]])
      elsif mapping[:debit] || mapping[:credit]
        # Separate debit/credit columns — debit is negative, credit is positive
        debit = parse_amount(row[mapping[:debit]])
        credit = parse_amount(row[mapping[:credit]])
        if debit && debit != 0
          -debit.abs
        elsif credit && credit != 0
          credit.abs
        end
      end
    end

    def parse_amount(value)
      return nil if value.blank?
      # Strip currency symbols, thousands separators, and whitespace
      cleaned = value.to_s.gsub(/[$€£,\s]/, "")
      # Handle parentheses as negative: (100.00) -> -100.00
      if cleaned.match?(/\A\([\d.]+\)\z/)
        cleaned = "-" + cleaned.tr("()", "")
      end
      return nil unless cleaned.match?(/\A-?[\d.]+\z/)
      (cleaned.to_f * 100).round
    end
  end
end

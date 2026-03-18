module Importers
  class BaseAdapter
    attr_reader :file_content, :account, :import_profile

    def initialize(file_content, account:, import_profile: nil)
      @file_content = file_content
      @account = account
      @import_profile = import_profile
    end

    # Returns an array of hashes, each representing a parsed transaction:
    #   { date:, description:, amount_cents:, transaction_type:, source_fingerprint:, memo: nil, posted_date: nil }
    def parse
      raise NotImplementedError, "#{self.class}#parse must return an array of transaction hashes"
    end

    private

    def generate_fingerprint(date:, description:, amount_cents:)
      Digest::SHA256.hexdigest("#{account.id}|#{date}|#{description}|#{amount_cents}")
    end

    def parse_date(date_string, format: nil)
      format ||= import_profile&.date_format
      if format.present?
        Date.strptime(date_string.strip, format)
      else
        Date.parse(date_string.strip)
      end
    rescue Date::Error
      nil
    end

    def correct_description(description)
      return description unless import_profile
      import_profile.apply_description_correction(description)
    end

    def determine_type(amount_cents)
      amount_cents.negative? ? :debit : :credit
    end
  end
end

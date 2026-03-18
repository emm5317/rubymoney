require 'rails_helper'

RSpec.describe Importers::CsvAdapter do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }

  describe "#parse" do
    it "parses a standard CSV with Date, Description, Amount columns" do
      csv = <<~CSV
        Date,Description,Amount
        2026-03-01,STARBUCKS COFFEE,-4.50
        2026-03-02,PAYROLL DEPOSIT,2500.00
      CSV

      adapter = described_class.new(csv, account: account)
      result = adapter.parse

      expect(result.size).to eq(2)

      debit = result[0]
      expect(debit[:date]).to eq(Date.new(2026, 3, 1))
      expect(debit[:description]).to eq("STARBUCKS COFFEE")
      expect(debit[:amount_cents]).to eq(-450)
      expect(debit[:transaction_type]).to eq(:debit)
      expect(debit[:source_fingerprint]).to be_present

      credit = result[1]
      expect(credit[:amount_cents]).to eq(250_000)
      expect(credit[:transaction_type]).to eq(:credit)
    end

    it "parses CSV with separate Debit and Credit columns" do
      csv = <<~CSV
        Date,Description,Debit,Credit
        2026-03-01,GROCERY STORE,45.00,
        2026-03-02,REFUND,,12.50
      CSV

      adapter = described_class.new(csv, account: account)
      result = adapter.parse

      expect(result.size).to eq(2)
      expect(result[0][:amount_cents]).to eq(-4500)
      expect(result[1][:amount_cents]).to eq(1250)
    end

    it "handles currency symbols and thousands separators" do
      csv = <<~CSV
        Date,Description,Amount
        2026-03-01,BIG PURCHASE,"$1,234.56"
      CSV

      adapter = described_class.new(csv, account: account)
      result = adapter.parse

      expect(result.first[:amount_cents]).to eq(123_456)
    end

    it "handles parentheses as negative amounts" do
      csv = <<~CSV
        Date,Description,Amount
        2026-03-01,WITHDRAWAL,(50.00)
      CSV

      adapter = described_class.new(csv, account: account)
      result = adapter.parse

      expect(result.first[:amount_cents]).to eq(-5000)
    end

    it "skips rows with missing date or description" do
      csv = <<~CSV
        Date,Description,Amount
        ,STARBUCKS,-4.50
        2026-03-01,,-4.50
        2026-03-01,VALID,-4.50
      CSV

      adapter = described_class.new(csv, account: account)
      result = adapter.parse

      expect(result.size).to eq(1)
      expect(result.first[:description]).to eq("VALID")
    end

    it "skips rows with zero amount" do
      csv = <<~CSV
        Date,Description,Amount
        2026-03-01,ZERO,0.00
        2026-03-01,VALID,-4.50
      CSV

      adapter = described_class.new(csv, account: account)
      result = adapter.parse

      expect(result.size).to eq(1)
    end

    it "generates unique fingerprints per transaction" do
      csv = <<~CSV
        Date,Description,Amount
        2026-03-01,STARBUCKS,-4.50
        2026-03-02,STARBUCKS,-4.50
      CSV

      adapter = described_class.new(csv, account: account)
      result = adapter.parse

      expect(result[0][:source_fingerprint]).not_to eq(result[1][:source_fingerprint])
    end

    it "applies description corrections from import profile" do
      profile = create(:import_profile, account: account, description_corrections: { "AMZN MKTP" => "Amazon" })

      csv = <<~CSV
        Date,Description,Amount
        2026-03-01,AMZN MKTP,-29.99
      CSV

      adapter = described_class.new(csv, account: account, import_profile: profile)
      result = adapter.parse

      expect(result.first[:description]).to eq("Amazon")
    end

    it "returns empty array for empty CSV" do
      adapter = described_class.new("", account: account)
      expect(adapter.parse).to eq([])
    end
  end
end

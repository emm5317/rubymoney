require 'rails_helper'

RSpec.describe ImportProcessor do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user, institution: "Chase") }

  describe "#preview" do
    it "parses a CSV file and stores preview data" do
      csv_content = <<~CSV
        Date,Description,Amount
        2026-03-01,STARBUCKS,-4.50
        2026-03-02,PAYROLL,2500.00
      CSV

      import = create(:import, account: account, file_type: :csv)
      import.file.attach(io: StringIO.new(csv_content), filename: "test.csv", content_type: "text/csv")

      processor = described_class.new(import)
      result = processor.preview

      expect(result.size).to eq(2)
      expect(import.reload.status).to eq("previewing")
      expect(import.preview_data.size).to eq(2)
      expect(import.total_rows).to eq(2)
    end
  end

  describe "#confirm" do
    it "creates transactions from preview data and marks import completed" do
      preview_data = [
        { date: "2026-03-01", description: "STARBUCKS", amount_cents: -450, transaction_type: "debit", source_fingerprint: "abc123" },
        { date: "2026-03-02", description: "PAYROLL", amount_cents: 250_000, transaction_type: "credit", source_fingerprint: "def456" }
      ]

      import = create(:import, account: account, status: :previewing, preview_data: preview_data, total_rows: 2)
      import.file.attach(io: StringIO.new("dummy"), filename: "test.csv", content_type: "text/csv")

      processor = described_class.new(import)
      result = processor.confirm

      expect(result[:imported]).to eq(2)
      expect(result[:skipped]).to eq(0)
      expect(import.reload.status).to eq("completed")
      expect(import.imported_count).to eq(2)
      expect(import.completed_at).to be_present
      expect(account.reload.last_imported_at).to be_present
    end

    it "skips duplicate transactions by fingerprint" do
      # Create an existing transaction with the same fingerprint
      create(:transaction, account: account, source_fingerprint: "abc123", description: "STARBUCKS")

      preview_data = [
        { date: "2026-03-01", description: "STARBUCKS", amount_cents: -450, transaction_type: "debit", source_fingerprint: "abc123" },
        { date: "2026-03-02", description: "NEW TXN", amount_cents: -1000, transaction_type: "debit", source_fingerprint: "new456" }
      ]

      import = create(:import, account: account, status: :previewing, preview_data: preview_data, total_rows: 2)
      import.file.attach(io: StringIO.new("dummy"), filename: "test.csv", content_type: "text/csv")

      processor = described_class.new(import)
      result = processor.confirm

      expect(result[:imported]).to eq(1)
      expect(result[:skipped]).to eq(1)
    end

    it "auto-categorizes imported transactions when rules exist" do
      groceries = create(:category, :groceries)
      create(:rule, category: groceries, match_value: "STARBUCKS", match_type: :contains, priority: 10)

      preview_data = [
        { date: "2026-03-01", description: "STARBUCKS COFFEE", amount_cents: -450, transaction_type: "debit", source_fingerprint: "cat123" }
      ]

      import = create(:import, account: account, status: :previewing, preview_data: preview_data, total_rows: 1)
      import.file.attach(io: StringIO.new("dummy"), filename: "test.csv", content_type: "text/csv")

      processor = described_class.new(import)
      result = processor.confirm

      expect(result[:categorized]).to eq(1)
      expect(import.transactions.first.category).to eq(groceries)
    end

    it "fails gracefully with no preview data" do
      import = create(:import, account: account, status: :previewing, preview_data: nil)
      import.file.attach(io: StringIO.new("dummy"), filename: "test.csv", content_type: "text/csv")

      processor = described_class.new(import)
      processor.confirm

      expect(import.reload.status).to eq("failed")
    end
  end
end

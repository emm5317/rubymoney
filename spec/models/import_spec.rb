require 'rails_helper'

RSpec.describe Import, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:import)).to be_valid
    end

    it "requires a file_name" do
      expect(build(:import, file_name: nil)).not_to be_valid
    end
  end

  describe "enums" do
    it "defines file_type" do
      expect(Import.file_types.keys).to include("csv", "ofx", "qfx", "pdf")
    end

    it "defines status with previewing" do
      expect(Import.statuses.keys).to include("pending", "previewing", "processing", "completed", "failed")
    end
  end

  describe "#rollback!" do
    it "deletes associated transactions and marks as failed" do
      import = create(:import, :completed)
      account = import.account
      create(:transaction, account: account, import: import, description: "Test 1")
      create(:transaction, account: account, import: import, description: "Test 2")

      expect { import.rollback! }.to change { Transaction.count }.by(-2)
      expect(import.reload.status).to eq("failed")
      expect(import.imported_count).to eq(0)
    end
  end
end

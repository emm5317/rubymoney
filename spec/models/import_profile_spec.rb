require 'rails_helper'

RSpec.describe ImportProfile, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:import_profile)).to be_valid
    end

    it "requires unique account + institution" do
      profile = create(:import_profile)
      dup = build(:import_profile, account: profile.account, institution: profile.institution)
      expect(dup).not_to be_valid
    end
  end

  describe "#apply_description_correction" do
    it "returns corrected description when known" do
      profile = build(:import_profile, description_corrections: { "AMZN MKTP US" => "Amazon" })
      expect(profile.apply_description_correction("AMZN MKTP US")).to eq("Amazon")
    end

    it "returns original description when unknown" do
      profile = build(:import_profile, description_corrections: {})
      expect(profile.apply_description_correction("STARBUCKS")).to eq("STARBUCKS")
    end
  end

  describe "#learn_description_correction!" do
    it "saves a new correction" do
      profile = create(:import_profile, description_corrections: {})
      profile.learn_description_correction!("AMZN", "Amazon")
      expect(profile.reload.description_corrections).to eq({ "AMZN" => "Amazon" })
    end
  end
end

require 'rails_helper'

RSpec.describe Category, type: :model do
  describe "validations" do
    it "is valid with a name" do
      expect(build(:category)).to be_valid
    end

    it "requires a name" do
      expect(build(:category, name: nil)).not_to be_valid
    end

    it "requires a unique name" do
      create(:category, name: "Groceries")
      expect(build(:category, name: "Groceries")).not_to be_valid
    end
  end

  describe "associations" do
    it "supports parent-child hierarchy" do
      parent = create(:category, name: "Food")
      child = create(:category, name: "Fast Food", parent: parent)
      expect(parent.children).to include(child)
      expect(child.parent).to eq(parent)
    end
  end

  describe "#full_name" do
    it "returns name for top-level category" do
      cat = build(:category, name: "Groceries")
      expect(cat.full_name).to eq("Groceries")
    end

    it "returns parent > name for subcategory" do
      parent = create(:category, name: "Food")
      child = build(:category, name: "Fast Food", parent: parent)
      expect(child.full_name).to eq("Food > Fast Food")
    end
  end
end

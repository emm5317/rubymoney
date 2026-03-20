require "rails_helper"

RSpec.describe "Tag Merge", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }

  before { sign_in user }

  describe "POST /tags/merge" do
    let!(:source) { create(:tag, name: "tax") }
    let!(:target) { create(:tag, name: "tax-deductible") }

    it "reassigns transaction_tags from source to target" do
      txn = create(:transaction, account: account)
      txn.tags << source

      post merge_tags_path, params: { source_id: source.id, target_id: target.id }
      expect(txn.reload.tags).to include(target)
      expect(txn.tags).not_to include(source)
    end

    it "skips duplicates when transaction already has target tag" do
      txn = create(:transaction, account: account)
      txn.tags << source
      txn.tags << target

      expect {
        post merge_tags_path, params: { source_id: source.id, target_id: target.id }
      }.not_to raise_error

      expect(txn.reload.tags).to contain_exactly(target)
    end

    it "deletes the source tag" do
      post merge_tags_path, params: { source_id: source.id, target_id: target.id }
      expect(Tag.exists?(source.id)).to be false
    end

    it "redirects with success notice" do
      post merge_tags_path, params: { source_id: source.id, target_id: target.id }
      expect(response).to redirect_to(tags_path)
      follow_redirect!
      expect(response.body).to include("merged into")
    end

    it "rejects merging a tag into itself" do
      post merge_tags_path, params: { source_id: source.id, target_id: source.id }
      expect(response).to redirect_to(tags_path)
      follow_redirect!
      expect(response.body).to include("Cannot merge a tag into itself")
    end

    it "requires authentication" do
      sign_out user
      post merge_tags_path, params: { source_id: source.id, target_id: target.id }
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end

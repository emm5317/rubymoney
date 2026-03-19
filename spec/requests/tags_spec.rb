require "rails_helper"

RSpec.describe "Tags", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /tags" do
    it "loads successfully" do
      get tags_path
      expect(response).to have_http_status(:ok)
    end

    it "lists tags" do
      create(:tag, name: "tax-deductible")
      get tags_path
      expect(response.body).to include("tax-deductible")
    end
  end

  describe "GET /tags/:id" do
    it "shows tag details" do
      tag = create(:tag, name: "reimbursable", color: "#10B981")
      get tag_path(tag)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("reimbursable")
    end
  end

  describe "GET /tags/new" do
    it "renders the form" do
      get new_tag_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /tags" do
    it "creates a valid tag" do
      expect {
        post tags_path, params: { tag: { name: "vacation", color: "#8B5CF6" } }
      }.to change(Tag, :count).by(1)
      expect(response).to redirect_to(tags_path)
      follow_redirect!
      expect(response.body).to include("Tag created")
    end

    it "rejects blank name" do
      post tags_path, params: { tag: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects duplicate name" do
      create(:tag, name: "existing")
      post tags_path, params: { tag: { name: "existing" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /tags/:id" do
    let!(:tag) { create(:tag, name: "old-tag") }

    it "updates the tag" do
      patch tag_path(tag), params: { tag: { name: "new-tag" } }
      expect(response).to redirect_to(tags_path)
      expect(tag.reload.name).to eq("new-tag")
    end

    it "rejects invalid update" do
      patch tag_path(tag), params: { tag: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /tags/:id" do
    let!(:tag) { create(:tag, name: "to-delete") }

    it "deletes and redirects" do
      expect {
        delete tag_path(tag)
      }.to change(Tag, :count).by(-1)
      expect(response).to redirect_to(tags_path)
    end
  end

  describe "authentication" do
    before { sign_out user }

    it "redirects unauthenticated users" do
      get tags_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end

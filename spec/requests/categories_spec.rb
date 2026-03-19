require "rails_helper"

RSpec.describe "Categories", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /categories" do
    it "loads successfully" do
      get categories_path
      expect(response).to have_http_status(:ok)
    end

    it "lists categories" do
      create(:category, name: "Groceries")
      get categories_path
      expect(response.body).to include("Groceries")
    end

    it "shows empty state with no categories" do
      get categories_path
      expect(response.body).to include("No categories")
    end
  end

  describe "GET /categories/:id" do
    it "shows category details" do
      cat = create(:category, name: "Dining Out", color: "#EF4444")
      get category_path(cat)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dining Out")
    end
  end

  describe "GET /categories/new" do
    it "renders the form" do
      get new_category_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /categories" do
    it "creates a valid category" do
      expect {
        post categories_path, params: { category: { name: "Transportation", color: "#3B82F6" } }
      }.to change(Category, :count).by(1)
      expect(response).to redirect_to(categories_path)
      follow_redirect!
      expect(response.body).to include("Category created")
    end

    it "rejects blank name" do
      post categories_path, params: { category: { name: "", color: "#3B82F6" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects duplicate name" do
      create(:category, name: "Groceries")
      post categories_path, params: { category: { name: "Groceries", color: "#3B82F6" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /categories/:id" do
    let!(:cat) { create(:category, name: "Old Name") }

    it "updates the category" do
      patch category_path(cat), params: { category: { name: "New Name" } }
      expect(response).to redirect_to(categories_path)
      expect(cat.reload.name).to eq("New Name")
    end

    it "rejects invalid update" do
      patch category_path(cat), params: { category: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /categories/:id" do
    let!(:cat) { create(:category, name: "To Delete") }

    it "deletes and redirects" do
      expect {
        delete category_path(cat)
      }.to change(Category, :count).by(-1)
      expect(response).to redirect_to(categories_path)
    end
  end

  describe "hierarchy" do
    it "creates a subcategory with parent" do
      parent = create(:category, name: "Food")
      post categories_path, params: { category: { name: "Fast Food", parent_id: parent.id, color: "#000" } }
      expect(Category.last.parent).to eq(parent)
    end
  end

  describe "authentication" do
    before { sign_out user }

    it "redirects unauthenticated users" do
      get categories_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end

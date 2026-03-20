Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root "dashboard#show", as: :authenticated_root
  end

  devise_scope :user do
    root to: "devise/sessions#new"
  end

  resource :dashboard, only: [:show], controller: "dashboard" do
    get :drilldown
  end

  resources :accounts do
    resources :imports, only: [:new, :create, :show, :index] do
      member do
        get  :preview
        post :confirm
        post :rollback
      end
    end
    resource :reconciliation, only: [:show, :update]
  end

  resource :transaction_review, only: [:show], path: "transactions/review", controller: "transaction_reviews" do
    post :apply
  end

  resources :transactions do
    member do
      patch :categorize
      patch :update_tags
      post  :create_rule
      post  :link_transfer
      delete :unlink_transfer
    end
    collection do
      get  :uncategorized
      get  :export
      post :bulk_categorize
      post :bulk_tag
    end
  end

  resources :recurring, only: [:index]

  resources :categories do
    collection do
      post :merge
    end
  end
  resources :budgets do
    collection do
      post :copy_previous
    end
  end
  resources :rules do
    collection do
      post :preview
    end
  end
  resources :tags do
    collection do
      post :merge
    end
  end

  resources :recurring_transactions, only: [:index, :show, :edit, :update, :destroy] do
    member do
      post :confirm
      post :dismiss
      post :reactivate
    end
    collection do
      post :detect_now
      post :mark_recurring
    end
  end

  # Top-level import shortcut
  get "import", to: "import_start#index", as: :import_start

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # good_job web UI (dev only)
  mount GoodJob::Engine => "/good_job" if Rails.env.development?
end

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
      post :bulk_categorize
      post :bulk_tag
    end
  end

  resources :categories
  resources :budgets do
    collection do
      post :copy_previous
    end
  end
  resources :rules
  resources :tags

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # good_job web UI (dev only)
  mount GoodJob::Engine => "/good_job" if Rails.env.development?
end

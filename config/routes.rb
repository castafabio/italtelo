Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: 'registrations'
  }
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root 'line_items#index'

  #SIDEKIQ
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'

  resources :aggregated_jobs do
    collection do
      get :aggregate
      get :scheduler
    end
    member do
      delete :delete_attachment
      match :send_to_switch, via: [:get, :post]
      match :upload_file, via: [:get, :post]
      match :add_line_items, via: [:get, :patch]
      patch :inline_update
      patch :toggle_is_active
    end
  end

  resources :customer_machines

  resources :customizations

  resources :cutters, only: :index do
    member do
      get :resend
    end
  end

  resources :line_items do
    member do
      delete :delete_attachment
      match :upload_file, via: [:get, :post]
      match :append_line_item, via: [:get, :patch]
      patch :toggle_is_active
      patch :deaggregate
      patch :inline_update
      post :send_to_switch
    end
  end

  resources :logs, only: :index

  resources :printers, only: :index do
    member do
      get :resend
    end
  end

  resources :roles

  resources :submit_points do
    collection do
      get :sync
    end
    resources :switch_fields, only: [:index] do
      member do
        patch :sort
      end
      collection do
        get :sort
      end
    end
  end

  resources :users do
    member do
      patch 'toggle_role/:role', action: :toggle_role, as: :toggle_role
    end
  end
end

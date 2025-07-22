Rails.application.routes.draw do
  get "reservations/new"
  get "reservations/create"
  devise_for :admin_users
  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  post '/callback' => 'linebot#callback'

  root to: "admin/dashboard#index"

  namespace :admin do
    get "notification_logs/index"
    get 'reservations/calendar', to: 'reservations#calendar'
    root to: "dashboard#index"
  
    resources :tickets, only: [:index, :create, :destroy] do
      post :use, on: :member
    end
  
    resources :ticket_templates, except: [:show]
    resources :ticket_usages, only: [:index, :new, :create, :edit, :update]
  
    resources :users, only: [:index, :edit, :update, :show], defaults: { format: :json } do
      resources :tickets, only: [:new, :create]
      get 'ticket_management', to: 'users#tickets', as: 'ticket_management'
      post 'tickets/create_from_template', to: 'tickets#create_from_template', as: 'create_ticket_from_template'
      get 'ticket_usages', to: 'users#ticket_usages'
    end

    resources :notification_logs, only: [:index, :destroy]
    resources :reservations do
      collection do
        get :available_slots
      end
    end
  end
  
  resources :users, only: [:edit, :update]
  resources :reservations, only: [:new, :create]
end


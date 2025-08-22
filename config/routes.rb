# config/routes.rb の正しい修正方法

Rails.application.routes.draw do
  # ルートページ
  root 'admin/dashboard#index'
  
  # 管理者用ルート
  namespace :admin do
    # ダッシュボード
    get 'dashboard', to: 'dashboard#index'
    
    # 管理者ルート
    root to: 'dashboard#index'
    
    # 予約管理
    resources :reservations do
      collection do
        get 'calendar'
        get 'cancellation_stats'
        get 'load_shift_settings'
        get 'load_reservations'
      end
    end
    
    # ユーザー管理
    resources :users do
      collection do
        get :search
      end
      member do
        get 'tickets'
        get 'history'
        get 'ticket_management'
        get 'ticket_usages'
      end
    end
    
    # チケット管理
    resources :tickets do
      member do
        patch 'use'
      end
      collection do
        post 'create_for_user'
      end
    end
    resources :ticket_templates
    resources :ticket_usages
    
    # 通知管理
    resources :notification_logs, only: [:index]
    resources :notification_preferences, only: [:index]
    
    # 設定
    resources :settings, only: [:index, :show, :edit, :update]
  end
  
  # 一般ユーザー用ルート
  namespace :public do
    resources :bookings, only: [:new, :create, :show]
  end
  
  # 予約管理（一般）
  resources :reservations, only: [:new, :create]
  
  # ユーザー管理（一般）
  resources :users, only: [:edit, :update]
  
  # LINE Bot
  post 'linebot/callback', to: 'linebot#callback'
  
  # ヘルスチェック
  get 'health', to: 'health#check'
  get 'up', to: 'health#check'
  
  # PWA
  get 'manifest.json', to: 'pwa#manifest'
  get 'service-worker.js', to: 'pwa#service_worker'
  
  # Devise
  devise_for :admin_users
end
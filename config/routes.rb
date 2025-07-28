# config/routes.rb の正しい修正方法

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
    root to: "dashboard#index"
    
    # 通知ログ
    resources :notification_logs, only: [:index, :destroy]
    
    # チケット関連
    resources :tickets, only: [:index, :create, :destroy] do
      post :use, on: :member
    end
    
    resources :ticket_templates, except: [:show]
    resources :ticket_usages, only: [:index, :new, :create, :edit, :update]
    
    # ユーザー管理
    resources :users, only: [:index, :new, :create, :edit, :update, :show, :destroy] do
      resources :tickets, only: [:new, :create]
      get 'ticket_management', to: 'users#tickets', as: 'ticket_management'
      post 'create_ticket_from_template', to: 'tickets#create_from_template', as: 'create_ticket_from_template'
      get 'ticket_usages', to: 'users#ticket_usages'
    end

    # 予約管理（修正版）
    # カレンダーのルートを最初に独立して定義
    get 'reservations/calendar', to: 'reservations#calendar', as: 'reservations_calendar'
    
    resources :reservations do
      collection do
        # 🆕 一括作成機能を追加
        get :bulk_new              # 一括作成フォーム表示
        post :bulk_create          # 一括作成実行
        
        # 既存の機能
        get :available_slots       # 空き時間取得
        patch :bulk_status_change  # 一括ステータス変更
      end
      
      member do
        # ステータス管理
        patch :cancel                    # 予約キャンセル
        patch :change_status            # ステータス変更
        
        # 繰り返し予約管理
        post :create_recurring          # 繰り返し予約作成
        patch :cancel_recurring         # 繰り返し予約停止
        get :child_reservations         # 子予約一覧取得
        
        # メール送信
        post :send_email               # メール送信（確認・リマインダー）
      end
    end
  end
  
  # 一般ユーザー用ルート
  resources :users, only: [:edit, :update]
  resources :reservations, only: [:new, :create]
end
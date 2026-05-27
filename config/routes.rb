Rails.application.routes.draw do
  devise_for :users

  resource :profile, only: [ :show, :edit, :update ]

  resources :transactions
  resources :financial_goals do
    member do
      post :create_plan
    end
  end
  resources :goals do
    member do
      post :execute_milestone
      post :complete_milestone
      post :create_plan
    end
  end

  get "agent/chat", to: "agent#chat"
  post "agent/ask", to: "agent#ask"
  get "agent/history", to: "agent#history"
  get "agent/session_messages", to: "agent#session_messages"

  root "agent#chat"
end

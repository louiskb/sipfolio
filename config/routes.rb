Rails.application.routes.draw do

  resources :chats do
    resources :messages, only: [:create]
  end
  
  resources :models, only: [:index, :show] do
    collection do
      post :refresh
    end
  end

  devise_for :users

  root to: "pages#home"

  get "/user-profile", to: "pages#user_profile", as: "user_profile"
  get "/journal", to: "pages#journal", as: "journal"

  resources :cocktails do
    resources :doses, only: [:new, :create, :destroy], shallow: true
    resources :tags, only: [:new, :create, :destroy], shallow: true
    resources :user_reviews, only: [:new, :create, :destroy]
    resource :favorite, only: [:create, :destroy]
  end

  resources :ingredients, only: [:new, :create]

  resources :profiles, only: [:show, :index] do
    resources :achievements, only: [:create, :destroy]
    resources :badges, only: [:create, :destroy]
    resources :follows, only: [:create, :destroy]
    resources :points, only: [:create, :destroy]
  end
end

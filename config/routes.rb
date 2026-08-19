Rails.application.routes.draw do
  root "dashboard#index"
  resources :gifts, only: [:index, :show] do
    member do
      post :designate
      post :refund
    end
  end
  get "up" => "rails/health#show", as: :rails_health_check
end

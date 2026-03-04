Rails.application.routes.draw do
  # Cities (REST)
  resources :cities, only: %i[index show]

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Root (opcional)
  # root "cities#index"
end

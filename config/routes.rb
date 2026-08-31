# frozen_string_literal: true

ActsAsCalculator::Engine.routes.draw do
  constraints(->(_request) { ActsAsCalculator.configuration.enable_api }) do
    resources :formulas, only: %i[index show create update destroy] do
      resources :versions, only: %i[index show create], controller: "formula_versions"
    end

    resources :templates, only: %i[index show create destroy] do
      member do
        post :preview
        post :promote
      end
    end

    post "import", to: "imports#create"
  end
end

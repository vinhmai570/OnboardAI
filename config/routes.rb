Rails.application.routes.draw do
  get "chat/create"
  get "courses/index"
  get "courses/show"
  get "courses/enroll"
  get "courses/complete_step"
  # Authentication routes
  resources :sessions, only: [ :new, :create, :destroy ]
  get "/login", to: "sessions#new"
  delete "/logout", to: "sessions#destroy"

  # Root route - redirect to appropriate dashboard
  root "dashboard#index"

  # User dashboard
  get "dashboard", to: "dashboard#index"
  get "dashboard/index"

  # Admin routes
  namespace :admin do
    get "course_steps/index"
    get "course_steps/new"
    get "course_steps/create"
    get "course_steps/edit"
    get "course_steps/update"
    get "course_steps/destroy"
    get "course_steps/move_up"
    get "course_steps/move_down"
    get "course_modules/index"
    get "course_modules/new"
    get "course_modules/create"
    get "course_modules/edit"
    get "course_modules/update"
    get "course_modules/destroy"
    get "course_modules/move_up"
    get "course_modules/move_down"
    # Course Generator with AI
    resources :course_generator, only: [ :index ] do
      collection do
        post :generate
        post :generate_detailed
        get :show_structure
        post :new_conversation
        post :switch_conversation
        get :search_documents
      end
    end
    get "courses/index"
    get "courses/new"
    get "courses/create"
    get "courses/show"
    get "courses/edit"
    get "courses/update"
    get "courses/destroy"
    get "courses/generate_tasks"
    get "courses/generate_details"
    get "courses/publish"
    get "users/index"
    get "users/new"
    get "users/create"
    get "users/edit"
    get "users/update"
    get "users/destroy"
    get "dashboard", to: "dashboard#index"
    get "dashboard/index"

    resources :users, except: [ :show ]
    resources :documents do
      member do
        post :process_document
      end
      collection do
        delete :bulk_delete
      end
    end
    resources :courses do
      member do
        post :generate_tasks
        post :generate_details
        patch :publish
      end
      resources :steps, except: [ :index, :show ]

      # New structured course resources
      resources :course_modules, except: [:show] do
        member do
          patch :move_up
          patch :move_down
        end
        resources :course_steps, except: [:show] do
          member do
            patch :move_up
            patch :move_down
          end
        end
      end
    end
  end

  # User-facing course routes
  resources :courses, only: [ :index, :show ] do
    member do
      post :enroll
      patch :complete_step
    end
    resources :steps, only: [ :show ]
  end

  # Chat API
  post "/chat", to: "chat#create"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end

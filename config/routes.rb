Rails.application.routes.draw do
  # Authentication routes
  resources :sessions, only: [ :new, :create, :destroy ]
  get "/login", to: "sessions#new"
  delete "/logout", to: "sessions#destroy"
  get "/logout", to: "sessions#destroy"  # Support both GET and DELETE for logout

  # Root route - redirect to appropriate dashboard
  root "dashboard#index"

  # User dashboard
  get "dashboard", to: "dashboard#index"

  # Admin routes
  namespace :admin do
    # Admin dashboard
    get "dashboard", to: "dashboard#index"

    # Course Generator with AI
    resources :course_generator, only: [ :index ] do
      collection do
        post :generate
        post :generate_detailed
        get :show_structure
        post :new_conversation
        post :switch_conversation
        delete :delete_conversation
        get :search_documents
        get 'step_content/:id', to: 'course_generator#step_content', as: 'step_content'
      end
      member do
        post :generate_full_course
        get :show_full_course
      end
    end

    # User management
    resources :users do
      member do
        post :assign_course
        delete :unassign_course
      end
    end

    # Document management
    resources :documents do
      member do
        post :process_document
      end
      collection do
        delete :bulk_delete
      end
    end

    # Course management with nested resources
    resources :courses do
      member do
        post :generate_tasks
        post :generate_details
        patch :publish
        post :assign_users
        delete 'unassign_user/:user_id', to: 'courses#unassign_user', as: 'unassign_user'
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
            get :quiz_check
          end
        end
      end
    end

    # Admin quiz management
    resources :quizzes do
      member do
        get :analytics
        post :regenerate
      end
    end

    # Progress Analytics
    resources :progress_analytics, only: [:index] do
      collection do
        get :course_details
        get :user_details
        get :export_analytics
      end
    end
  end

  # User-facing course routes
  resources :courses, only: [ :index, :show ] do
    member do
      post :enroll
      patch :complete_step
    end
    collection do
      get 'step_content/:id', to: 'courses#step_content', as: 'step_content'
      get 'quiz_check/:course_id/:course_module_id/:step_id', to: 'courses#quiz_check', as: 'quiz_check'
    end
    resources :steps, only: [ :show ]
  end

  # Quiz routes for users
  resources :quizzes, only: [ :show ] do
    member do
      post :start
      get :start # Handle direct GET access to start URL
      patch :submit
      get :results
      patch :save_progress
      post :check_answer # Real-time answer checking
    end
  end

  # Progress tracking routes
  resources :progress, only: [ :index ] do
    collection do
      get :dashboard
      get 'course/:course_id', to: 'progress#course_progress', as: 'course_progress'
      post 'step/:course_step_id/start', to: 'progress#start_step', as: 'start_step'
      patch 'step/:course_step_id/complete', to: 'progress#complete_step', as: 'complete_step'
    end
  end

  # Chat API
  post "/chat", to: "chat#create"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end

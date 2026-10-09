# Routes for GlowBook - Indonesian beauty & wellness booking marketplace

Rails.application.routes.draw do
  get "manifest", to: "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
  get "service-worker", to: "rails/pwa#service_worker", as: :pwa_service_worker, defaults: { format: :js }
  post "bahasa/:locale", to: "locales#update", as: :locale

  get "notifikasi", to: "notifications#index", as: :notifications
  patch "notifikasi/baca-semua", to: "notifications#mark_all_read", as: :mark_all_notifications_read
  patch "notifikasi/:id/baca", to: "notifications#mark_read", as: :read_notification

  get "akun/pesan", to: "chats#index", defaults: { audience: "customer" }, as: :account_chats
  get "bisnis/pesan", to: "chats#index", defaults: { audience: "business" }, as: :dashboard_chats
  post "b/:slug/chat", to: "chats#start", as: :business_chat
  get "chat/:id", to: "chats#show", as: :chat
  post "chat/:id/pesan", to: "chats#create", as: :chat_messages
  get "chat/:id/pesan", to: "chats#poll", as: :chat_messages_feed

  devise_for :users,
             controllers: { omniauth_callbacks: "users/omniauth_callbacks", registrations: "users/registrations" },
             path_names: { sign_in: "masuk", sign_out: "keluar", sign_up: "daftar" }

  devise_scope :user do
    get "/daftar", to: "devise/registrations#new", as: :signup
    get "/masuk", to: "devise/sessions#new", as: :login
    delete "/keluar", to: "devise/sessions#destroy", as: :logout
  end

  # Customer dashboard
  namespace :account, path: "akun" do
    root to: "dashboard#show"
    get "booking", to: "bookings#index", as: :bookings
    get "favorit", to: "favorites#index", as: :favorites
    get "ulasan", to: "reviews#index", as: :reviews
    get "profil", to: "profiles#show", as: :profile
    patch "profil", to: "profiles#update"
    get "pengaturan", to: "settings#show", as: :settings
  end

  # Cancel/reschedule bookings (customer)
  resources :bookings, only: [ :show ], path: "booking" do
    member do
      patch :cancel
      get :reschedule, path: "ubah-jadwal"
      patch :update_schedule, path: "update-jadwal"
    end
  end
  post "booking/:reference/payment", to: "booking_payments#create", as: :booking_payment
  post "midtrans/notifications", to: "midtrans_notifications#create", as: :midtrans_notifications

  # Public marketplace
  root "home#index"
  get "cari", to: "searches#index", as: :search
  post "cari/terdekat", to: "searches#nearby", as: :nearby_search
  get "kota/:slug", to: "cities#show", as: :city
  get "kategori/:slug", to: "categories#show", as: :category
  get "untuk-bisnis", to: "pages#business", as: :for_business
  get "daftar-bisnis", to: "pages#business_signup", as: :registrasi_bisnis
  post "daftar-bisnis", to: "business_registrations#create", as: :buat_registrasi_bisnis

  # Booking flow (multi-step) — explicit routes: slug-based, matching the
  # business_book_* helpers used across views/controllers.
  get "b/:slug/book", to: "bookings_flow#new", as: :business_book
  get "b/:slug/book/step/:step", to: "bookings_flow#show", as: :business_book_step
  patch "b/:slug/book/step/:step", to: "bookings_flow#update", as: :business_book_update
  get "b/:slug/book/confirmation", to: "bookings_flow#confirmation", as: :business_book_confirmation
  post "b/:slug/book/complete", to: "bookings_flow#complete", as: :business_book_complete

  # Business detail
  get "b/:slug", to: "businesses#show", as: :business_detail
  get "b/:slug/tabs/:tab", to: "businesses#tab", as: :business_tab

  # Business owner dashboard
  namespace :dashboard, path: "bisnis" do
    root to: "dashboard#index", as: :root
    get "kalender", to: "calendars#show", as: :calendar
    get "booking", to: "bookings#index", as: :bookings
    patch "booking/:id/status", to: "bookings#update_status", as: :booking_status
    get "layanan", to: "services#index", as: :services
    get "staff", to: "staffs#index", as: :staffs
    get "pelanggan", to: "customers#index", as: :customers
    get "promosi", to: "promotions#index", as: :promotions
    get "analitik", to: "analytics#show", as: :analytics
    get "keuangan", to: "payments#index", as: :finance
    get "profil-bisnis", to: "profiles#show", as: :profile
    patch "profil-bisnis", to: "profiles#update"
    resources :blocked_times, except: %i[new show], path: "blokir-waktu"
    get "staff/:staff_id/jadwal", to: "staff_availability#show", as: :staff_availability
    post "staff/:staff_id/jadwal/salin", to: "staff_availability#copy_hours", as: :copy_staff_hours
    post "staff/:staff_id/jadwal/shift", to: "staff_availability#create_shift", as: :staff_shifts
    patch "staff/:staff_id/jadwal/shift/:id", to: "staff_availability#update_shift", as: :staff_shift
    delete "staff/:staff_id/jadwal/shift/:id", to: "staff_availability#destroy_shift"
    post "staff/:staff_id/jadwal/istirahat", to: "staff_availability#create_break", as: :staff_breaks
    patch "staff/:staff_id/jadwal/istirahat/:id", to: "staff_availability#update_break", as: :staff_break
    delete "staff/:staff_id/jadwal/istirahat/:id", to: "staff_availability#destroy_break"
    resources :galleries, only: %i[index create destroy], path: "galeri"
    get "pengaturan", to: "settings#show", as: :settings

    resources :services, only: %i[new create edit update destroy], as: :manage_services
    resources :staffs, only: %i[new create edit update destroy], as: :manage_staffs
    resources :promotions, only: %i[new create edit update destroy], as: :manage_promotions do
      member { patch :toggle }
    end
  end

  # Admin
  namespace :admin, path: "admin" do
    root to: "dashboard#index"
    resources :users, only: %i[index show destroy], path: "pengguna"
    resources :businesses, only: %i[index show destroy], path: "bisnis" do
      member { patch :activate }
      member { patch :reactivate }
    end
    resources :bookings, only: %i[index show], path: "booking" do
      member { patch :update_status }
    end
    get "pembayaran", to: "payments#index", as: :payments
    resources :categories, only: %i[index create edit update destroy], path: "kategori" do
      member { patch :toggle_popular }
    end
    resources :reviews, only: %i[index destroy], path: "ulasan"
    resources :promotions, only: %i[index destroy], path: "promosi"
    get "laporan", to: "reports#index", as: :reports
    get "pengaturan", to: "settings#show", as: :settings
    patch "pengaturan", to: "settings#update"
  end

  # Favorites (customer)
  post "b/:slug/favorite", to: "favorites#create", as: :business_favorite
  delete "b/:slug/favorite", to: "favorites#destroy", as: :business_unfavorite

  # Reviews (customer) — nested under business slug
  post "b/:slug/reviews", to: "reviews#create", as: :business_reviews
  get "b/:slug/reviews/new", to: "reviews#new", as: :new_business_review

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end

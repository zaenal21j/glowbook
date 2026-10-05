class CreateGlowbookSchema < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
    enable_extension "btree_gist" unless extension_enabled?("btree_gist")

    create_table :cities, force: :cascade do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end
    add_index :cities, :slug, unique: true

    create_table :categories, force: :cascade do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :icon_name
      t.string :tagline
      t.integer :position, null: false, default: 0
      t.boolean :is_popular, null: false, default: false
      t.timestamps
    end
    add_index :categories, :slug, unique: true
    add_index :categories, :is_popular

    create_table :users, force: :cascade do |t|
      t.string :name, null: false, default: ""
      t.string :phone
      t.integer :role, null: false, default: 0
      t.string :remote_avatar_url
      ## Devise columns
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip
      t.string   :provider
      t.string   :uid
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :role
    add_index :users, [:provider, :uid], unique: true

    create_table :businesses, force: :cascade do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :address, null: false
      t.string :phone, null: false
      t.references :owner, null: false, foreign_key: { to_table: :users }, index: true
      t.references :city, null: false, foreign_key: true
      t.decimal :latitude, precision: 9, scale: 6
      t.decimal :longitude, precision: 9, scale: 6
      t.float :avg_rating
      t.integer :status, null: false, default: 0
      t.timestamps
    end
    add_index :businesses, :slug, unique: true
    add_index :businesses, :status
    add_index :businesses, :avg_rating

    create_table :business_categories, force: :cascade do |t|
      t.references :business, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.timestamps
    end
    add_index :business_categories, [:business_id, :category_id], unique: true

    create_table :business_hours, force: :cascade do |t|
      t.references :business, null: false, foreign_key: true
      t.integer :weekday, null: false # 0=Sunday..6=Saturday
      t.integer :open_minute, null: false # minutes from midnight, e.g. 540 = 09:00
      t.integer :close_minute, null: false
      t.boolean :closed, null: false, default: false
      t.timestamps
    end
    add_index :business_hours, [:business_id, :weekday], unique: true

    create_table :services, force: :cascade do |t|
      t.references :business, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :duration_minutes, null: false
      t.integer :price, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :services, [:business_id, :active]

    create_table :staffs, force: :cascade do |t|
      t.references :business, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :name, null: false
      t.string :title
      t.string :avatar_color
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :staffs, [:business_id, :name]

    create_table :staff_schedules, force: :cascade do |t|
      t.references :staff, null: false, foreign_key: { to_table: :staffs }
      t.integer :weekday, null: false
      t.integer :start_minute, null: false
      t.integer :end_minute, null: false
      t.timestamps
    end
    add_index :staff_schedules, [:staff_id, :weekday]
    add_index :staff_schedules, [:staff_id, :weekday, :start_minute], unique: true

    create_table :staff_breaks, force: :cascade do |t|
      t.references :staff, null: false, foreign_key: { to_table: :staffs }
      t.integer :weekday, null: false
      t.integer :start_minute, null: false
      t.integer :end_minute, null: false
      t.timestamps
    end
    add_index :staff_breaks, [:staff_id, :weekday]

    create_table :blocked_times, force: :cascade do |t|
      t.references :business, null: false, foreign_key: true
      t.references :staff, foreign_key: { to_table: :staffs }
      t.string :reason, null: false
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.timestamps
    end
    add_index :blocked_times, [:business_id, :staff_id, :start_time]

    create_table :bookings, force: :cascade do |t|
      t.references :user, null: false, foreign_key: true
      t.references :business, null: false, foreign_key: true
      t.string :reference, null: false
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.integer :status, null: false, default: 0
      t.bigint :total_amount, null: false, default: 0
      t.string :notes
      t.string :payment_method
      t.timestamps
    end
    add_index :bookings, :reference, unique: true
    add_index :bookings, [:user_id, :status]
    add_index :bookings, [:business_id, :status]
    add_index :bookings, [:user_id, :start_time]

    create_table :booking_items, force: :cascade do |t|
      t.references :booking, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.references :staff, foreign_key: { to_table: :staffs }
      t.integer :price, null: false
      t.integer :duration_minutes, null: false
      t.tstzrange :during
      t.timestamps
    end
    add_index :booking_items, :during, using: :gist
    execute <<~SQL
      ALTER TABLE booking_items ADD CONSTRAINT no_overlapping_bookings
        EXCLUDE USING gist (
          staff_id WITH =,
          during WITH &&
        ) WHERE (during IS NOT NULL AND staff_id IS NOT NULL)
    SQL
    add_index :booking_items, [:booking_id, :service_id]

    create_table :reviews, force: :cascade do |t|
      t.references :user, null: false, foreign_key: true
      t.references :business, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :comment
      t.timestamps
    end
    add_index :reviews, [:user_id, :business_id], unique: true
    add_index :reviews, [:business_id, :created_at]

    create_table :favorites, force: :cascade do |t|
      t.references :user, null: false, foreign_key: true
      t.references :business, null: false, foreign_key: true
      t.timestamps
    end
    add_index :favorites, [:user_id, :business_id], unique: true

    create_table :promotions, force: :cascade do |t|
      t.references :business, null: false, foreign_key: true
      t.string :title, null: false
      t.string :code
      t.string :description
      t.integer :discount_percent
      t.datetime :starts_at
      t.datetime :ends_at
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :promotions, [:business_id, :active]

    create_table :business_galleries, force: :cascade do |t|
      t.references :business, null: false, foreign_key: true
      t.string :caption
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end

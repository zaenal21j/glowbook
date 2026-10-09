class Business < ApplicationRecord
  belongs_to :owner, class_name: "User"
  belongs_to :city

  has_one_attached :cover_image
  has_one_attached :logo_image

  has_many :business_categories, dependent: :destroy
  has_many :categories, through: :business_categories
  has_many :business_hours, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :staff, dependent: :destroy
  has_many :blocked_times, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :promotions, dependent: :destroy
  has_many :business_galleries, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :customers, -> { distinct }, through: :bookings, source: :user

  accepts_nested_attributes_for :business_hours

  validates :name, presence: true, length: { maximum: 150 }
  validates :slug, presence: true, uniqueness: true
  validates :owner, presence: true
  validates :city, presence: true
  validates :address, presence: true
  validates :phone, presence: true, format: { with: /\A\+?[0-9]{8,15}\z/ }
  validates :latitude, allow_nil: true, numericality: { in: -90..90 }
  validates :longitude, allow_nil: true, numericality: { in: -180..180 }
  validates :avg_rating, numericality: { in: 0..5 }, allow_nil: true

  enum :status, { active: 0, pending: 1, suspended: 2 }, default: :active

  scope :active, -> { where(status: :active) }
  scope :in_city, ->(slug) { joins(:city).where(cities: { slug: slug }) }
  scope :open_today, -> { joins(:business_hours).where(business_hours: { weekday: Date.current.wday, closed: false }) }
  scope :with_category, ->(slug) { joins(:categories).where(categories: { slug: slug }) }
  scope :min_rating, ->(r) { where("avg_rating >= ?", r.to_f) if r.present? }
  scope :has_promo, -> { joins(:promotions).merge(Promotion.active_now).distinct }
  scope :highest_rated, -> { where("avg_rating >= 4.5").order(avg_rating: :desc) }
  scope :search, ->(q) { where("businesses.name ILIKE :q OR businesses.address ILIKE :q", q: "%#{q}%") if q.present? }
  scope :with_any_category, ->(slugs) { joins(:categories).where(categories: { slug: slugs }).distinct }
  scope :price_between, ->(min, max) {
    sub = Service.active.select("business_id, MIN(price) AS min_price").group(:business_id).to_sql
    scope = joins("JOIN (#{sub}) svc ON svc.business_id = businesses.id")
    scope = scope.where("svc.min_price >= ?", min.to_i) if min.present?
    scope = scope.where("svc.min_price <= ?", max.to_i) if max.present?
    scope
  }
  scope :by_rating, -> { order(avg_rating: :desc).order(:name) }
  scope :by_min_price, -> {
    service_prices = Service.active.select("business_id, MIN(price) AS lowest_service_price").group(:business_id).to_sql
    joins("LEFT JOIN (#{service_prices}) service_prices ON service_prices.business_id = businesses.id")
      .select("businesses.*, service_prices.lowest_service_price")
      .order(Arel.sql("lowest_service_price ASC NULLS LAST"))
      .order(:name)
  }
  scope :near_point, ->(latitude, longitude) {
    latitude = Float(latitude).round(6)
    longitude = Float(longitude).round(6)
    distance = <<~SQL.squish
      6371 * acos(LEAST(1.0, GREATEST(-1.0,
        cos(radians(#{latitude})) * cos(radians(businesses.latitude)) *
        cos(radians(businesses.longitude) - radians(#{longitude})) +
        sin(radians(#{latitude})) * sin(radians(businesses.latitude))
      )))
    SQL

    select("businesses.*, (#{distance}) AS distance_km")
      .order(Arel.sql("distance_km ASC NULLS LAST"))
      .order(:name)
  }

  def self.ransackable_attributes(_auth = nil)
    %w[name city_id]
  end

  def opening_hour(day = Date.current)
    business_hours.find_by(weekday: day.wday)
  end

  def open_today?
    h = opening_hour
    h.present? && !h.closed?
  end

  def open_now?
    return false unless open_today?

    now = Time.zone.now
    h = opening_hour
    now_minute = now.hour * 60 + now.min
    now_minute >= h.open_minute && now_minute < h.close_minute
  end

  def price_from
    services.active.minimum(:price) || 0
  end

  def rating_label
    avg_rating ? format("%.1f", avg_rating) : I18n.t("display.new_business")
  end

  def categories_list
    categories.order(:name).limit(3).pluck(:name).join(" · ")
  end

  def service_categories_list
    services.joins(:category).distinct.order("categories.name").pluck("categories.name").first(3).join(" · ")
  end

  def active_promotions
    promotions.active_now
  end

  def reviews_count
    reviews.count
  end

  def to_param
    slug
  end
end

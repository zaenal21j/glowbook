class Service < ApplicationRecord
  belongs_to :business
  belongs_to :category

  has_many :booking_items, dependent: :destroy
  has_many :staff_services, dependent: :destroy
  has_many :staff, through: :staff_services

  validates :business, presence: true
  validates :name, presence: true, length: { maximum: 120 }
  validates :duration_minutes, presence: true, numericality: { only_integer: true, in: 15..(12 * 60) }
  validates :price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :category, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
  scope :for_categories, ->(slugs) { joins(:category).where(categories: { slug: Array(slugs) }) }

  def price_idr
    "Rp #{ActionController::Base.helpers.number_with_delimiter(price, delimiter: '.')}"
  end
end

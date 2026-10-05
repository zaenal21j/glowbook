class City < ApplicationRecord
  has_many :businesses, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }

  scope :ordered, -> { order(:name) }
end

class BusinessGallery < ApplicationRecord
  belongs_to :business
  has_one_attached :image

  validates :business, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end

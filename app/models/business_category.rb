class BusinessCategory < ApplicationRecord
  belongs_to :business
  belongs_to :category

  validates :business, presence: true
  validates :category, presence: true
  validates :category_id, uniqueness: { scope: :business_id }
end

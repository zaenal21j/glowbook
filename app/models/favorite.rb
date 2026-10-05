class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :business

  validates :user, presence: true
  validates :business, presence: true
  validates :user_id, uniqueness: { scope: :business_id }

  scope :recent, -> { order(created_at: :desc) }
end

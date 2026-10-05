class Review < ApplicationRecord
  belongs_to :user
  belongs_to :business

  validates :user, presence: true
  validates :business, presence: true
  validates :rating, presence: true, numericality: { only_integer: true, in: 1..5 }
  validates :comment, length: { maximum: 1000 }
  validates :user_id, uniqueness: { scope: :business_id, message: "sudah memberi ulasan untuk bisnis ini" }

  scope :recent, -> { order(created_at: :desc) }
  scope :with_comment, -> { where.not(comment: [nil, ""]) }

  after_commit :recalculate_business_rating, on: %i[create update destroy]

  def stars
    "★" * rating + "☆" * (5 - rating)
  end

  private

  def recalculate_business_rating
    business.update_column(:avg_rating, business.reviews.average(:rating)&.round(1))
  end
end

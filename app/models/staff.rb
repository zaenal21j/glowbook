class Staff < ApplicationRecord
  belongs_to :business
  belongs_to :user, optional: true

  has_one_attached :avatar

  has_many :staff_schedules, dependent: :destroy
  has_many :staff_breaks, dependent: :destroy
  has_many :blocked_times, dependent: :destroy
  has_many :staff_services, dependent: :destroy
  has_many :services, through: :staff_services
  has_many :booking_items, dependent: :destroy

  validates :business, presence: true
  validates :name, presence: true, length: { maximum: 120 }
  validates :title, allow_blank: true, length: { maximum: 80 }

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(active: true) }

  def display_title
    title.presence || "Terapis"
  end

  def works_on?(weekday)
    staff_schedules.exists?(weekday: weekday)
  end
end

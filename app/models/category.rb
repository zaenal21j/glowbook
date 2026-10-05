class Category < ApplicationRecord
  has_many :business_categories, dependent: :destroy
  has_many :businesses, through: :business_categories
  has_many :services, dependent: :nullify

  validates :name, presence: true, length: { maximum: 80 }
  validates :slug, presence: true, uniqueness: true

  scope :ordered, -> { order(:position, :name) }
  scope :popular, -> { where(is_popular: true).ordered }

  # Heroicons-style outline paths for the homepage category icons
  ICONS = {
    "rambut" => "M1.5 8.25c0-2.25 3.75-4.5 8.25-4.5h4.5c4.5 0 8.25 2.25 8.25 4.5M4 16.5c6 1.5 10 1.5 16 0M9 9.5c.5 3.5 5.5 3.5 6 0M12 4v13",
    "facial" => "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18ZM9 10h.01M15 10h.01M9.5 15a4.5 4.5 0 0 0 5 0",
    "nail" => "M9 3h6v6a3 3 0 1 1-6 0V3ZM12 12v9M9 21h6",
    "massage" => "M4 12a8 8 0 0 1 16 0M6 15c2 2.5 10 2.5 12 0M12 4v4",
    "spa" => "M12 21c-4-3-7-6-7-9.5A4.5 4.5 0 0 1 12 8a4.5 4.5 0 0 1 7 3.5c0 3.5-3 6.5-7 9.5ZM12 8c0-2 1-4 3-5-1 2.5-.5 4-.5 5",
    "barber" => "M6 4l6 6M18 4l-6 6M7 20a2.5 2.5 0 1 0 5 0v-6M12 20a2.5 2.5 0 1 0 5 0v-6M6 4a2 2 0 1 1-4 0 2 2 0 0 1 4 0ZM18 4a2 2 0 1 0 4 0 2 2 0 0 0-4 0Z",
    "makeup" => "M9 3h6l-1 7h-4L9 3ZM12 10v10M9 20h6",
    "eyelash" => "M2 12s3.5-5 10-5 10 5 10 5M6 12c1.5 1.5 3.5 2.5 6 2.5s4.5-1 6-2.5",
    "hair-coloring" => "M4 20h16M6 20V9a6 6 0 0 1 12 0v11M12 3v3",
    "lash-lift" => "M3 13c2.5 2 6 3 9 3s6.5-1 9-3M7 13l-1.5-2M12 14v-2.5M17 13l1.5-2"
  }.freeze

  def icon_path
    ICONS[slug]
  end
end

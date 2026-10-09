class Promotion < ApplicationRecord
  belongs_to :business

  validates :business, presence: true
  validates :title, presence: true, length: { maximum: 120 }
  validates :code, allow_blank: true, uniqueness: { scope: :business_id }
  validates :discount_percent, numericality: { only_integer: true, in: 1..90 }, allow_nil: true
  validate  :ends_after_starts, if: -> { starts_at.present? && ends_at.present? }

  scope :active_now, -> { where(active: true).where("starts_at IS NULL OR starts_at <= ?", Time.current)
                          .where("ends_at IS NULL OR ends_at >= ?", Time.current) }

  private

  def ends_after_starts
    return if ends_at > starts_at

    errors.add(:ends_at, I18n.t("scheduling.errors.end_after_start"))
  end
end

class BusinessGallery < ApplicationRecord
  belongs_to :business
  has_one_attached :image

  validates :business, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :caption, length: { maximum: 255 }, allow_nil: true
  validate :image_must_be_supported

  private

  def image_must_be_supported
    unless image.attached?
      errors.add(:image, I18n.t("validation.gallery.required"))
      return
    end

    unless %w[image/jpeg image/png image/webp].include?(image.content_type)
      errors.add(:image, I18n.t("validation.gallery.type"))
    end
    errors.add(:image, I18n.t("validation.gallery.size")) if image.blob.byte_size > 10.megabytes
  end
end

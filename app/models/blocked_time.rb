class BlockedTime < ApplicationRecord
  belongs_to :business
  belongs_to :staff, optional: true

  validates :business, presence: true
  validates :reason, presence: true, length: { maximum: 255 }
  validates :start_time, :end_time, presence: true
  validate  :end_after_start
  validate :staff_belongs_to_business

  scope :overlapping, ->(range) { where("start_time < ? AND end_time > ?", range.last, range.first) }
  scope :for_staff, ->(staff) { where(staff_id: [nil, staff]) }

  private

  def end_after_start
    return if start_time.nil? || end_time.nil? || start_time < end_time

    errors.add(:end_time, I18n.t("scheduling.errors.end_after_start"))
  end

  def staff_belongs_to_business
    return if staff_id.blank? || (staff.present? && staff.business_id == business_id)

    errors.add(:staff, I18n.t("scheduling.errors.foreign_staff"))
  end
end

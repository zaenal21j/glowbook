class BlockedTime < ApplicationRecord
  belongs_to :business
  belongs_to :staff, optional: true

  validates :business, presence: true
  validates :reason, presence: true
  validates :start_time, :end_time, presence: true
  validate  :end_after_start

  scope :overlapping, ->(range) { where("start_time < ? AND end_time > ?", range.last, range.first) }
  scope :for_staff, ->(staff) { where(staff_id: [nil, staff]) }

  private

  def end_after_start
    return if start_time < end_time

    errors.add(:end_time, "harus setelah waktu mulai")
  end
end

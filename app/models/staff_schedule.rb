class StaffSchedule < ApplicationRecord
  belongs_to :staff

  validates :staff, presence: true
  validates :weekday, presence: true, inclusion: { in: 0..6 }
  validates :start_minute, :end_minute, presence: true, numericality: { only_integer: true, in: 0..(24 * 60) }
  validates :start_minute, uniqueness: { scope: [:staff_id, :weekday] }
  validate  :end_after_start

  private

  def end_after_start
    return if start_minute < end_minute

    errors.add(:end_minute, "harus setelah jam mulai")
  end
end

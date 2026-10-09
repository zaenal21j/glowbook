class StaffSchedule < ApplicationRecord
  belongs_to :staff

  validates :staff, presence: true
  validates :weekday, presence: true, inclusion: { in: 0..6 }
  validates :start_minute, :end_minute, presence: true, numericality: { only_integer: true, in: 0..(24 * 60) }
  validates :start_minute, uniqueness: { scope: [:staff_id, :weekday] }
  validate  :end_after_start
  validate :no_overlapping_shifts

  private

  def end_after_start
    return if start_minute.nil? || end_minute.nil? || start_minute < end_minute

    errors.add(:end_minute, I18n.t("scheduling.errors.end_after_start"))
  end

  def no_overlapping_shifts
    return if staff.nil? || weekday.nil? || start_minute.nil? || end_minute.nil?

    if staff.staff_schedules.where(weekday: weekday).where.not(id: id)
            .where("start_minute < ? AND end_minute > ?", end_minute, start_minute).exists?
      errors.add(:base, I18n.t("scheduling.errors.overlap"))
    end
  end
end

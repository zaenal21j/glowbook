class StaffBreak < ApplicationRecord
  belongs_to :staff

  validates :staff, presence: true
  validates :weekday, presence: true, inclusion: { in: 0..6 }
  validates :start_minute, :end_minute, presence: true, numericality: { only_integer: true, in: 0..(24 * 60) }
  validate  :end_after_start

  private

  def end_after_start
    return if start_minute.nil? || end_minute.nil? || start_minute < end_minute

    errors.add(:end_minute, I18n.t("scheduling.errors.end_after_start"))
  end
end

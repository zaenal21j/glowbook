class BookingItem < ApplicationRecord
  belongs_to :booking
  belongs_to :service
  belongs_to :staff, optional: true

  validates :booking, presence: true
  validates :service, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :duration_minutes, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate  :staff_must_serve_service, if: -> { staff.present? && service.present? }

  scope :active, -> { where.not(during: nil) }

  # PostgreSQL exclusion constraint prevents overlapping active appointments
  # for the same staff member. Cancelled bookings have during = NULL (exempt).

  def label
    service.name
  end

  private

  def staff_must_serve_service
    return if staff.services.include?(service)

    errors.add(:staff, "tidak melayani layanan ini")
  end
end

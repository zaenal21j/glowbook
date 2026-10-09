class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :business

  has_many :booking_items, dependent: :destroy
  has_many :payment_attempts, dependent: :restrict_with_exception
  has_many :services, through: :booking_items

  STATUSES = %w[pending confirmed completed cancelled no_show].freeze
  PAYMENT_METHODS = %w[pay_at_venue online_transfer].freeze

  validates :user, presence: true
  validates :business, presence: true
  validates :reference, presence: true, uniqueness: true
  validates :start_time, :end_time, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :payment_method, inclusion: { in: PAYMENT_METHODS, allow_nil: true }
  validate  :end_after_start
  validate  :not_in_past, on: :create
  validate  :items_belong_to_business

  enum :status, { pending: 0, confirmed: 1, completed: 2, cancelled: 3, no_show: 4 }, default: :pending

  scope :upcoming, -> { where(status: %w[pending confirmed]).where("start_time >= ?", Time.current).order(:start_time) }
  scope :upcoming_order, -> { where("start_time >= ?", Time.current) }
  scope :past, -> { where(status: %w[completed no_show]).order(start_time: :desc) }
  scope :on_date, ->(date) { where("start_time >= ? AND start_time < ?", date.beginning_of_day, date.end_of_day) }
  scope :for_week, ->(week_start) { where("start_time >= ? AND start_time < ?", week_start, week_start + 7.days) }
  scope :in_month, ->(month) {
    month_start = month.to_date.beginning_of_month.beginning_of_day
    where(start_time: month_start...month_start.next_month)
  }

  before_validation :generate_reference, on: :create

  def duration_minutes
    ((end_time - start_time) / 60).to_i
  end

  def status_badge_class
    case status
    when "pending" then "badge-amber"
    when "confirmed" then "badge-green"
    when "completed" then "badge-gray"
    when "cancelled", "no_show" then "badge-red"
    end
  end

  def cancellable?
    (pending? || confirmed?) && !payment_attempts.where(status: %w[pending settlement capture]).exists?
  end

  def reschedulable?
    cancellable? && start_time > 2.hours.from_now
  end

  def completable?
    confirmed? && end_time <= Time.current
  end

  def no_showable?
    confirmed? && start_time <= Time.current
  end

  def complete!
    with_lock do
      unless completable?
        errors.add(:status, I18n.t("validation.booking.complete_after_end"))
        raise ActiveRecord::RecordInvalid, self
      end

      update!(status: :completed)
    end
  end

  def mark_no_show!
    with_lock do
      unless no_showable?
        errors.add(:status, I18n.t("validation.booking.no_show_after_start"))
        raise ActiveRecord::RecordInvalid, self
      end

      update!(status: :no_show)
    end
  end

  def cancel!
    with_lock do
      raise ActiveRecord::RecordInvalid, self unless cancellable?

      booking_items.update_all(during: nil, updated_at: Time.current)
      update!(status: :cancelled)
    end
  end

  def self.next_reference_for(date)
    seq = (where("reference LIKE ?", "GB-#{date.strftime('%Y%m%d')}-%").maximum(:reference) || "").split("-").last.to_i
    format("GB-%s-%06d", date.strftime("%Y%m%d"), seq + 1)
  end

  private

  def generate_reference
    self.reference ||= self.class.next_reference_for(start_time.to_date)
  end

  def end_after_start
    return if start_time.blank? || end_time.blank?
    return if end_time > start_time

    errors.add(:end_time, I18n.t("scheduling.errors.end_after_start"))
  end

  def not_in_past
    return if start_time.blank? || start_time > 10.minutes.ago

    errors.add(:start_time, I18n.t("validation.booking.not_in_past"))
  end

  def items_belong_to_business
    return if booking_items.blank?

    booking_items.each do |item|
      next if item.service&.business_id == business_id

      errors.add(:base, I18n.t("validation.booking.foreign_service"))
    end
  end
end

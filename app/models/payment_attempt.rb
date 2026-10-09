class PaymentAttempt < ApplicationRecord
  belongs_to :booking

  STATUSES = %w[pending settlement capture expire cancel deny failure refund].freeze

  validates :order_id, presence: true, uniqueness: true
  validates :amount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }

  scope :latest_first, -> { order(created_at: :desc, id: :desc) }
  scope :paid, -> {
    where(status: "settlement").or(where(status: "capture", provider_status: "capture"))
  }

  def paid?
    status == "settlement" || (status == "capture" && provider_status == "capture")
  end
end

class PaymentAttempt < ApplicationRecord
  belongs_to :booking

  STATUSES = %w[pending settlement capture expire cancel deny failure refund].freeze

  validates :order_id, presence: true, uniqueness: true
  validates :amount, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :provider, inclusion: { in: %w[midtrans duitku] }
  validates :gateway_environment, inclusion: { in: %w[sandbox production] }, if: -> { provider == "duitku" }
  validates :merchant_code, presence: true, if: -> { provider == "duitku" }

  scope :latest_first, -> { order(created_at: :desc, id: :desc) }
  scope :production_payments, -> { where(provider: "duitku", gateway_environment: "production") }
  scope :paid, -> {
    where(status: "settlement").or(where(status: "capture", provider_status: "capture"))
  }

  def paid?
    status == "settlement" || (status == "capture" && provider_status == "capture")
  end

  def gateway_label
    return "Midtrans · #{I18n.t('duitku.legacy')}" if provider == "midtrans"

    "Duitku · #{I18n.t("duitku.#{gateway_environment}")}"
  end

  def status_badge_class
    return "badge-green" if paid?
    return "badge-amber" if status == "pending"

    "badge-red"
  end
end

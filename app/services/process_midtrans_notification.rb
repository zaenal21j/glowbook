require "digest"
require "bigdecimal"

class ProcessMidtransNotification
  class InvalidNotification < StandardError; end

  SUCCESS_STATES = %w[settlement capture].freeze
  KNOWN_STATES = (SUCCESS_STATES + %w[pending expire cancel deny failure refund]).freeze

  def initialize(payload:, client: MidtransClient.new, server_key: Rails.configuration.x.midtrans_server_key)
    @payload = payload.stringify_keys
    @client = client
    @server_key = server_key
  end

  def call
    verify_signature!
    attempt = PaymentAttempt.find_by!(order_id: @payload.fetch("order_id"))
    verify_amount!(attempt, @payload.fetch("gross_amount"))

    status = @client.transaction_status(attempt.order_id)
    raise InvalidNotification, "Order ID dari Midtrans tidak cocok." unless status["order_id"] == attempt.order_id
    verify_amount!(attempt, status.fetch("gross_amount"))
    raise InvalidNotification, "Mata uang transaksi tidak cocok." unless status["currency"] == "IDR"

    apply_status(attempt, status)
  rescue KeyError, ArgumentError, ActiveRecord::RecordNotFound
    raise InvalidNotification, "Notifikasi pembayaran tidak valid."
  end

  private

  def verify_signature!
    expected = Digest::SHA512.hexdigest(
      [ @payload.fetch("order_id"), @payload.fetch("status_code"), @payload.fetch("gross_amount"), @server_key ].join
    )
    received = @payload.fetch("signature_key").to_s
    raise InvalidNotification, "Signature notifikasi tidak valid." unless received.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(expected, received)
  end

  def verify_amount!(attempt, amount)
    parsed_amount = BigDecimal(amount.to_s)
    raise InvalidNotification, "Nominal pembayaran tidak cocok." unless parsed_amount == BigDecimal(attempt.amount.to_s)
  end

  def apply_status(attempt, response)
    provider_status = response.fetch("transaction_status")
    raise InvalidNotification, "Status transaksi tidak dikenal." unless KNOWN_STATES.include?(provider_status)
    if provider_status == "capture" && response["fraud_status"] != "accept"
      provider_status = "deny"
    end

    attempt.with_lock do
      attributes = {
        status: provider_status,
        provider_status: response["transaction_status"],
        transaction_id: response["transaction_id"],
        payment_type: response["payment_type"]
      }
      attributes[:settled_at] = Time.current if SUCCESS_STATES.include?(provider_status) && attempt.settled_at.nil?
      attempt.update!(attributes)
    end
    attempt
  end
end

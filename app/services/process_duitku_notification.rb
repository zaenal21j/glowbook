require "bigdecimal"

class ProcessDuitkuNotification
  class InvalidNotification < StandardError; end

  def initialize(payload:, client: DuitkuClient.new(allow_disabled: true))
    @payload = payload.stringify_keys
    @client = client
  end

  def call
    raise InvalidNotification unless @payload.fetch("merchantCode") == @client.merchant_code && @client.valid_signature?(@payload)

    attempt = PaymentAttempt.find_by!(provider: "duitku", order_id: @payload.fetch("merchantOrderId"),
      merchant_code: @client.merchant_code, gateway_environment: @client.environment)
    verify_amount!(attempt, @payload.fetch("amount"))
    reference = @payload.fetch("reference")
    raise InvalidNotification unless reference.is_a?(String) && reference.present?
    raise InvalidNotification if attempt.transaction_id.present? && attempt.transaction_id != reference

    ReconcileDuitkuPayment.new(attempt: attempt, client: @client).call(expected_reference: reference)
  rescue KeyError, ArgumentError, ActiveRecord::RecordNotFound, ReconcileDuitkuPayment::InvalidStatus
    raise InvalidNotification
  end

  private

  def verify_amount!(attempt, amount)
    value = amount.to_s
    raise InvalidNotification unless value.match?(/\A\d+(?:\.0+)?\z/) && BigDecimal(value) == BigDecimal(attempt.amount.to_s)
  end
end

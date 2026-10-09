require "bigdecimal"

class ReconcileDuitkuPayment
  class InvalidStatus < StandardError; end
  STATES = { "00" => "settlement", "01" => "pending", "02" => "cancel" }.freeze

  def initialize(attempt:, client: DuitkuClient.new(allow_disabled: true))
    @attempt = attempt
    @client = client
  end

  def call(expected_reference: @attempt.transaction_id, manual: false)
    unless @attempt.provider == "duitku" && @attempt.merchant_code == @client.merchant_code && @attempt.gateway_environment == @client.environment
      raise InvalidStatus
    end
    @attempt.with_lock do
      return @attempt if @attempt.paid?
      if manual
        raise InvalidStatus if @attempt.status_checked_at && @attempt.status_checked_at > 30.seconds.ago
        @attempt.update!(status_checked_at: Time.current)
      end
    end

    response = @client.transaction_status(@attempt.order_id)
    reference = response.fetch("reference")
    amount = response.fetch("amount").to_s
    unless response.fetch("merchantOrderId") == @attempt.order_id && reference.is_a?(String) && reference.present? &&
        (expected_reference.blank? || reference == expected_reference) &&
        amount.match?(/\A\d+(?:\.0+)?\z/) && BigDecimal(amount) == BigDecimal(@attempt.amount.to_s)
      raise InvalidStatus
    end
    state = STATES.fetch(response.fetch("statusCode"))
    @attempt.with_lock do
      return @attempt if @attempt.paid?
      raise InvalidStatus if @attempt.transaction_id.present? && @attempt.transaction_id != reference
      return @attempt if state == "pending" && @attempt.status != "pending"

      attributes = { status: state, provider_status: response["statusCode"], transaction_id: reference, status_checked_at: Time.current }
      attributes[:settled_at] = Time.current if state == "settlement"
      @attempt.update!(attributes)
    end
    @attempt
  rescue KeyError, ArgumentError, ActiveRecord::RecordNotUnique
    raise InvalidStatus
  end
end

require "securerandom"

class CreateBookingPayment
  Result = Data.define(:payment_attempt, :error) do
    def ok?
      error.nil?
    end
  end

  def initialize(booking:, client: nil)
    @booking = booking
    @client = client
  end

  def call
    @client ||= DuitkuClient.new
    attempt = IntegrationSetting.with_duitku_lock do
      @client.current_configuration? ? prepare_attempt : :previous_gateway
    end
    return Result.new(payment_attempt: nil, error: I18n.t("alerts.payment.not_payable")) if attempt == :ineligible
    return Result.new(payment_attempt: attempt, error: I18n.t("alerts.payment.already_paid")) if attempt == :paid
    return Result.new(payment_attempt: attempt, error: I18n.t("alerts.payment.processing")) if attempt == :processing
    return Result.new(payment_attempt: nil, error: I18n.t("duitku.previous_gateway")) if attempt == :previous_gateway
    if attempt.redirect_url.present?
      raise DuitkuClient::Error, I18n.t("duitku.invalid_checkout") unless @client.valid_checkout_url?(attempt.redirect_url)
      return Result.new(payment_attempt: attempt, error: nil)
    end

    @client.create_invoice(attempt)
    Result.new(payment_attempt: attempt, error: nil)
  rescue DuitkuClient::AmbiguousError => e
    attempt&.update(provider_status: "invoice_creation_unknown") if attempt.is_a?(PaymentAttempt)
    Result.new(payment_attempt: attempt, error: e.message)
  rescue DuitkuClient::Error, ActiveRecord::RecordInvalid => e
    if attempt.is_a?(PaymentAttempt)
      attempt.with_lock { attempt.update(status: "failure", provider_status: "invoice_creation_failed") unless attempt.paid? }
    end
    Result.new(payment_attempt: attempt, error: e.message)
  end

  private

  def prepare_attempt
    @booking.with_lock do
      return :ineligible unless @booking.confirmed? && @booking.payment_method == "online_transfer" && @booking.total_amount.positive?
      return :paid if @booking.payment_attempts.paid.exists?

      current = @booking.payment_attempts.where(status: "pending").order(created_at: :desc).first
      if current && (current.provider != "duitku" || current.gateway_environment != @client.environment || current.merchant_code != @client.merchant_code)
        return :previous_gateway
      end
      return current if current&.redirect_url.present?
      if current
        return :processing if current.updated_at > 30.seconds.ago

        current.touch
        return current
      end

      PaymentAttempt.create!(
        booking: @booking,
        provider: "duitku", gateway_environment: @client.environment, merchant_code: @client.merchant_code,
        order_id: "#{@booking.reference}-#{SecureRandom.hex(4)}",
        amount: @booking.total_amount
      )
    end
  end
end

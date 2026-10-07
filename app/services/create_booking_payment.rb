require "securerandom"

class CreateBookingPayment
  Result = Data.define(:payment_attempt, :error) do
    def ok?
      error.nil?
    end
  end

  def initialize(booking:, client: MidtransClient.new)
    @booking = booking
    @client = client
  end

  def call
    attempt = prepare_attempt
    return Result.new(payment_attempt: nil, error: "Booking ini tidak lagi dapat dibayar.") if attempt == :ineligible
    return Result.new(payment_attempt: attempt, error: "Pembayaran booking ini sudah berhasil.") if attempt == :paid
    return Result.new(payment_attempt: attempt, error: "Pembayaran sedang diproses. Muat ulang halaman beberapa saat lagi.") if attempt == :processing
    return Result.new(payment_attempt: attempt, error: nil) if attempt.redirect_url.present?

    @client.create_snap_transaction(attempt)
    Result.new(payment_attempt: attempt, error: nil)
  rescue MidtransClient::AmbiguousError => e
    attempt&.update(provider_status: "token_creation_unknown") if attempt.is_a?(PaymentAttempt)
    Result.new(payment_attempt: attempt, error: e.message)
  rescue MidtransClient::Error, ActiveRecord::RecordInvalid => e
    attempt&.update(status: "failure", provider_status: "token_creation_failed") if attempt.is_a?(PaymentAttempt)
    Result.new(payment_attempt: attempt, error: e.message)
  end

  private

  def prepare_attempt
    @booking.with_lock do
      return :ineligible unless @booking.confirmed? && @booking.payment_method == "online_transfer"
      return :paid if @booking.payment_attempts.exists?(status: %w[settlement capture])

      current = @booking.payment_attempts.where(status: "pending").order(created_at: :desc).first
      return current if current&.redirect_url.present?
      if current
        return :processing if current.updated_at > 30.seconds.ago

        current.touch
        return current
      end

      PaymentAttempt.create!(
        booking: @booking,
        order_id: "#{@booking.reference}-#{SecureRandom.hex(4)}",
        amount: @booking.total_amount
      )
    end
  end
end

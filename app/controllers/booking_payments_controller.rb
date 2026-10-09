class BookingPaymentsController < ApplicationController
  before_action :authenticate_user!

  def create
    booking = current_user.bookings.includes(:payment_attempts).find_by!(reference: params[:reference])
    return redirect_to booking_path(booking.reference), alert: t("alerts.payment.online_disabled") unless DuitkuClient.enabled?
    return redirect_to booking_path(booking.reference), alert: t("alerts.payment.wrong_method") unless booking.payment_method == "online_transfer"
    return redirect_to booking_path(booking.reference), alert: t("alerts.payment.not_payable") unless booking.confirmed?

    result = CreateBookingPayment.new(booking: booking).call
    if result.ok?
      redirect_to result.payment_attempt.redirect_url, allow_other_host: true
    else
      redirect_to booking_path(booking.reference), alert: result.error
    end
  end

  def refresh
    booking = current_user.bookings.find_by!(reference: params[:reference])
    attempt = booking.payment_attempts.where(provider: "duitku").latest_first.first!
    ReconcileDuitkuPayment.new(attempt: attempt).call(manual: true)
    redirect_to booking_path(booking.reference), notice: t("duitku.status_updated")
  rescue ReconcileDuitkuPayment::InvalidStatus, DuitkuClient::Error
    redirect_to booking_path(booking.reference), alert: t("duitku.status_unavailable")
  end
end

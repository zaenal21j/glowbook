class BookingsController < ApplicationController
  before_action :set_booking, only: %i[show cancel reschedule update_schedule]
  before_action :authorize_owner!, only: %i[show cancel reschedule update_schedule]

  def show
    @latest_payment_attempt = @booking.payment_attempts.latest_first.first
  end

  def cancel
    @booking.cancel!
    BookingNotificationDelivery.new(booking: @booking, event: :cancellation).call
    redirect_to booking_path(@booking.reference), notice: t("alerts.booking.cancelled")
  rescue ActiveRecord::RecordInvalid
    redirect_to booking_path(@booking.reference), alert: t("alerts.booking.cancel_failed")
  end

  def reschedule
    return redirect_to booking_path(@booking.reference), alert: t("alerts.booking.reschedule_unavailable") unless @booking.reschedulable?

    @selected_date = Date.iso8601(params[:date].to_s) if params[:date].present?
    @selected_date ||= @booking.start_time.to_date
    @slots = BookingSequenceAvailability.new(business: @booking.business,
      booking: @booking, date: @selected_date).slots
  rescue Date::Error
    redirect_to reschedule_booking_path(@booking.reference), alert: t("alerts.booking.select_new_slot")
  end

  def update_schedule
    return redirect_to booking_path(@booking.reference), alert: t("alerts.booking.reschedule_unavailable") unless @booking.reschedulable?

    date, time = schedule_selection
    if date.nil? || time.nil? || time.to_date != date
      return redirect_to reschedule_booking_path(@booking.reference), alert: t("alerts.booking.select_new_slot")
    end

    result = BookingRescheduler.new(booking: @booking, start_time: time).call
    unless result.ok?
      return redirect_to reschedule_booking_path(@booking.reference, date: date.iso8601), alert: result.error
    end

    BookingNotificationDelivery.new(booking: @booking, event: :reschedule).call
    redirect_to booking_path(@booking.reference), notice: t("alerts.booking.rescheduled")
  end

  private

  def set_booking
    @booking = Booking.find_by!(reference: params[:reference] || params[:id])
  end

  def authorize_owner!
    return if @booking.user == current_user || current_user&.admin? || @booking.business.owner == current_user

    redirect_to root_path, alert: t("alerts.access.booking_forbidden")
  end

  def schedule_selection
    [Date.iso8601(params[:date].to_s), Time.zone.iso8601(params[:time].to_s).in_time_zone]
  rescue ArgumentError, TypeError
    [nil, nil]
  end
end

class Dashboard::BookingsController < Dashboard::BaseController
  def index
    order = params[:status].in?(%w[pending confirmed]) ? :asc : :desc

    case params[:status]
    when "pending" then scope = @business.bookings.where(status: :pending)
    when "confirmed" then scope = @business.bookings.where(status: :confirmed)
    when "completed" then scope = @business.bookings.where(status: :completed)
    when "cancelled" then scope = @business.bookings.where(status: :cancelled)
    when "no_show" then scope = @business.bookings.where(status: :no_show)
    else
      scope = table_requested_controls("bookings").present? ? @business.bookings : @business.bookings.where(status: %w[pending confirmed]).upcoming_order
      order = :asc
    end

    @bookings = paginate(scope.includes(:user, booking_items: [ :service, :staff ]).order(start_time: order))
  end

  def update_status
    booking = @business.bookings.find(params[:id])
    notification_event = nil

    case params[:status]
    when "cancelled"
      booking.cancel!
      notification_event = :cancellation
    when "completed"
      booking.complete!
    when "no_show"
      booking.mark_no_show!
    else
      return redirect_to dashboard_bookings_path, alert: t("alerts.booking.invalid_status")
    end

    BookingNotificationDelivery.new(booking: booking, event: notification_event).call if notification_event
    redirect_to dashboard_bookings_path(status: params[:return_status].presence), notice: t("alerts.booking.status_updated")
  rescue ActiveRecord::RecordInvalid
    redirect_to dashboard_bookings_path(status: params[:return_status].presence), alert: t("alerts.booking.transition_failed")
  end
end

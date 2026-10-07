class Dashboard::BookingsController < Dashboard::BaseController
  def index
    case params[:status]
    when "pending" then scope = @business.bookings.where(status: :pending)
    when "confirmed" then scope = @business.bookings.where(status: :confirmed)
    when "completed" then scope = @business.bookings.past
    when "cancelled" then scope = @business.bookings.where(status: :cancelled)
    else scope = @business.bookings.where(status: %w[pending confirmed]).upcoming_order
    end
    @bookings = scope.includes(:user, booking_items: [ :service, :staff ]).order(start_time: :desc).limit(100)
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
      return redirect_to dashboard_bookings_path, alert: "Status booking tidak valid."
    end

    BookingNotificationDelivery.new(booking: booking, event: notification_event).call if notification_event
    redirect_to dashboard_bookings_path(status: params[:return_status].presence), notice: "Status booking berhasil diperbarui."
  rescue ActiveRecord::RecordInvalid
    redirect_to dashboard_bookings_path(status: params[:return_status].presence), alert: "Perubahan status tidak dapat dilakukan untuk booking ini."
  end
end

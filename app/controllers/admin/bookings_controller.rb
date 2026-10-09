class Admin::BookingsController < Admin::BaseController
  def index
    scope = case params[:status]
    when "pending" then Booking.where(status: :pending)
    when "confirmed" then Booking.where(status: :confirmed)
    when "completed" then Booking.where(status: :completed)
    when "cancelled" then Booking.where(status: :cancelled)
    when "no_show" then Booking.where(status: :no_show)
    else Booking.all
    end

    query = params[:q].to_s.strip
    if query.present?
      escaped_query = ActiveRecord::Base.sanitize_sql_like(query)
      scope = scope.left_joins(:user, :business).where(
        "bookings.reference ILIKE :q OR users.name ILIKE :q OR users.email ILIKE :q OR businesses.name ILIKE :q",
        q: "%#{escaped_query}%"
      )
    end

    @bookings = paginate(scope.includes(:user, :business, booking_items: [ :service, :staff ])
                              .order(start_time: :desc))
    @counts = { all: Booking.count, pending: Booking.where(status: :pending).count,
                confirmed: Booking.where(status: :confirmed).count,
                completed: Booking.where(status: :completed).count,
                cancelled: Booking.where(status: :cancelled).count,
                no_show: Booking.where(status: :no_show).count }
  end

  def show
    @booking = Booking.includes(:user, :business, :payment_attempts, booking_items: [ :service, :staff ]).find(params[:id])
  end

  def update_status
    booking = Booking.find(params[:id])
    notification_event = nil

    case params[:status]
    when "cancelled"
      booking.cancel!
      notification_event = :cancellation
      notice = I18n.t("admin.bookings.flash.cancelled")
    when "completed"
      booking.complete!
      notice = I18n.t("admin.bookings.flash.completed")
    when "no_show"
      booking.mark_no_show!
      notice = I18n.t("admin.bookings.flash.no_show")
    else
      return redirect_to admin_booking_path(booking), alert: I18n.t("admin.bookings.flash.invalid_status")
    end

    BookingNotificationDelivery.new(booking: booking, event: notification_event).call if notification_event
    redirect_to admin_booking_path(booking), notice: notice
  rescue ActiveRecord::RecordInvalid
    redirect_to admin_booking_path(params[:id]), alert: I18n.t("admin.bookings.flash.transition_failed")
  end
end

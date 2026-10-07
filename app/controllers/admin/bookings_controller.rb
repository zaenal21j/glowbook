class Admin::BookingsController < Admin::BaseController
  def index
    scope = case params[:status]
    when "pending" then Booking.where(status: :pending)
    when "confirmed" then Booking.where(status: :confirmed)
    when "completed" then Booking.past
    when "cancelled" then Booking.where(status: :cancelled)
    else Booking.all
    end

    @bookings = paginate(scope.includes(:user, :business, booking_items: [ :service, :staff ])
                              .order(start_time: :desc))
    @counts = { all: Booking.count, pending: Booking.where(status: :pending).count,
                confirmed: Booking.where(status: :confirmed).count,
                completed: Booking.past.count, cancelled: Booking.where(status: :cancelled).count }
  end

  def show
    @booking = Booking.find(params[:id])
  end
end

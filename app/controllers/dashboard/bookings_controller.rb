class Dashboard::BookingsController < Dashboard::BaseController
  def index
    case params[:status]
    when "pending" then scope = @business.bookings.where(status: :pending)
    when "confirmed" then scope = @business.bookings.where(status: :confirmed)
    when "completed" then scope = @business.bookings.past
    when "cancelled" then scope = @business.bookings.where(status: :cancelled)
    else scope = @business.bookings.where(status: %w[pending confirmed]).upcoming_order
    end
    @bookings = scope.includes(:user, booking_items: [:service, :staff]).order(start_time: :desc).limit(100)
  end
end

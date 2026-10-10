class Dashboard::DashboardController < Dashboard::BaseController
  def index
    @upcoming = paginate(@business.bookings.upcoming.includes(:user, booking_items: [:service, :staff]))
    @today_count = @business.bookings.on_date(Date.current).where(status: %w[pending confirmed]).count
    @week_count = @business.bookings.for_week(Date.current.beginning_of_week).count
    @revenue_month = @business.bookings.completed.in_month(Date.current.beginning_of_month).sum(:total_amount)
    @customer_count = @business.customers.count
    @rating = @business.avg_rating
  end
end

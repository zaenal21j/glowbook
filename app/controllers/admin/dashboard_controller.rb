class Admin::DashboardController < Admin::BaseController
  def index
    @total_users = User.count
    @total_customers = User.customers.count
    @total_businesses = Business.count
    @active_businesses = Business.active.count
    @total_bookings = Booking.count
    @bookings_this_month = Booking.in_month(Time.current.beginning_of_month).count
    @total_revenue = Booking.completed.sum(:total_amount)
    @pending_businesses = Business.pending.count

    @recent_bookings = paginate(Booking.includes(:user, :business, booking_items: [:service]).order(created_at: :desc))
    @top_businesses = Business.active.where.not(avg_rating: nil).by_rating.limit(5)
    @popular_categories = Category.popular.limit(6)

    @chart = AdminCharts.new(scope_date: 29.days.ago.to_date..Date.current)
    @chart_bookings = @chart.daily_counts
    @chart_revenue = @chart.daily_revenue
  end
end

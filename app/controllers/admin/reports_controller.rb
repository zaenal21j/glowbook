class Admin::ReportsController < Admin::BaseController
  def index
    @month = params[:month].present? ? Date.parse("#{params[:month]}-01") : Time.current.to_date.beginning_of_month
    month_start = @month.beginning_of_month
    month_end = month_start.end_of_month

    month_scope = Booking.where(start_time: month_start.beginning_of_day..month_end.end_of_day)
                         .where(status: %w[pending confirmed completed])

    @kpi_bookings = month_scope.count
    @kpi_revenue = month_scope.sum(:total_amount)
    @kpi_customers = User.customers.where(created_at: month_start.beginning_of_day..month_end.end_of_day).count
    @kpi_new_businesses = Business.where(created_at: month_start.beginning_of_day..month_end.end_of_day).count

    @by_city = month_scope.joins(business: :city)
                          .group("cities.name")
                          .sum("bookings.total_amount")
                          .sort_by { |_, v| -v }

    @by_category = month_scope.joins(booking_items: { service: :category })
                              .group("categories.name")
                              .sum("booking_items.price")
                              .sort_by { |_, v| -v }

    @top_businesses = month_scope.joins(:business)
                                 .group("businesses.name")
                                 .sum("bookings.total_amount")
                                 .sort_by { |_, v| -v }
                                 .first(10)
  end
end

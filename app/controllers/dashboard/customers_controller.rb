class Dashboard::CustomersController < Dashboard::BaseController
  def index
    @customers = @business.customers
                          .select("users.*, COUNT(DISTINCT bookings.id) AS bookings_count, SUM(bookings.total_amount) AS total_spent, MAX(bookings.start_time) AS last_visit")
                          .group("users.id")
                          .order("bookings_count DESC")
                          .limit(200)
  end
end

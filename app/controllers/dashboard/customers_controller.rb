class Dashboard::CustomersController < Dashboard::BaseController
  def index
    customer_scope = @business.customers
                              .select("users.*, COUNT(DISTINCT bookings.id) AS bookings_count, SUM(bookings.total_amount) AS total_spent, MAX(bookings.start_time) AS last_visit")
                              .group("users.id")
                              .order("bookings_count DESC")

    @total_customer_count = @business.customers.count
    @customers = paginate(customer_scope, total_count: @total_customer_count)
  end
end

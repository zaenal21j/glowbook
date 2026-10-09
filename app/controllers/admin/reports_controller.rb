class Admin::ReportsController < Admin::BaseController
  def index
    @month = selected_month
    month_start = @month.beginning_of_month
    month_end = month_start.end_of_month

    month_scope = completed_bookings(month_start, month_end)

    @kpi_bookings = month_scope.count
    @kpi_revenue = month_scope.sum(:total_amount)
    paid_attempts = PaymentAttempt.paid.joins(:booking)
                                   .where(settled_at: month_start.beginning_of_day..month_end.end_of_day)
    @kpi_online_payments = paid_attempts.distinct.count(:booking_id)
    @kpi_online_collected = paid_attempts.sum(:amount)
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

    respond_to do |format|
      format.html
      format.csv do
        send_data bookings_csv(month_scope), filename: "glowbook-bookings-#{@month.strftime('%Y-%m')}.csv",
                                             type: "text/csv; charset=utf-8"
      end
    end
  end

  private

  def selected_month
    return Time.current.to_date.beginning_of_month if params[:month].blank?

    Date.strptime(params[:month], "%Y-%m").beginning_of_month
  rescue Date::Error, ArgumentError
    Time.current.to_date.beginning_of_month
  end

  def completed_bookings(month_start, month_end)
    Booking.where(start_time: month_start.beginning_of_day..month_end.end_of_day)
           .where(status: :completed)
  end

  def bookings_csv(month_scope)
    rows = month_scope.includes(:user, business: :city, booking_items: :service).order(:start_time)
    data = []
    data << I18n.t("exports.booking_headers")
    rows.each do |booking|
      data << [
        booking.reference,
        booking.start_time.in_time_zone.strftime("%Y-%m-%d %H:%M"),
        booking.business.name,
        booking.business.city.name,
        booking.user.full_name,
        booking.user.email,
        booking.booking_items.map(&:label).join(", "),
        booking.total_amount,
        booking.status
      ]
    end

    "\uFEFF#{data.map { |row| row.map { |value| csv_cell(value) }.join(",") }.join("\r\n")}\r\n"
  end

  def csv_cell(value)
    text = value.to_s
    text = "'#{text}" if text.match?(/\A[[:space:][:cntrl:]]*[=+\-@]/)
    %Q("#{text.gsub('"', '""')}")
  end
end

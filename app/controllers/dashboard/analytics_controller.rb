class Dashboard::AnalyticsController < Dashboard::BaseController
  def show
    @revenue_month = @business.bookings.past.where("start_time >= ?", Date.current.beginning_of_month).sum(:total_amount)
    @bookings_month = @business.bookings.where("start_time >= ?", Date.current.beginning_of_month).count
    @new_customers = @business.customers.where("bookings.start_time >= ?", Date.current.beginning_of_month).limit(100).count
    @rating = @business.avg_rating

    # Pendapatan harian 30 hari terakhir (fill gap manual)
    from = 29.days.ago.to_date
    raw = @business.bookings.unscope(:order)
                   .where(status: %w[completed no_show])
                   .where(start_time: from.beginning_of_day..Date.current.end_of_day)
                   .group("DATE(bookings.start_time)")
                   .sum(:total_amount)
    @daily = (from..Date.current).index_with { |d| raw[d.to_s].to_f + raw[d].to_f }

    # Layanan terpopuler bulan ini
    @top_services = BookingItem.joins(:booking)
                               .where(bookings: { business_id: @business.id })
                               .joins(:service)
                               .where("booking_items.created_at >= ?", Date.current.beginning_of_month)
                               .group("services.name")
                               .count
                               .sort_by { |_, v| -v }
                               .first(5)
  end
end

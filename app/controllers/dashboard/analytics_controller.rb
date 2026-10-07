class Dashboard::AnalyticsController < Dashboard::BaseController
  def show
    completed_bookings = @business.bookings.completed
    @completed_value_month = completed_bookings.where("start_time >= ?", Date.current.beginning_of_month).sum(:total_amount)
    @bookings_month = @business.bookings.where("start_time >= ?", Date.current.beginning_of_month).count
    @new_customers = @business.customers.where("bookings.start_time >= ?", Date.current.beginning_of_month).count
    @rating = @business.avg_rating

    # Nilai booking selesai 30 hari terakhir (fill gap manual)
    from = 29.days.ago.to_date
    raw_completed_values = completed_bookings.unscope(:order)
                                            .where(start_time: from.beginning_of_day..Date.current.end_of_day)
                                            .group("DATE(bookings.start_time)")
                                            .sum(:total_amount)
    @daily_completed_values = (from..Date.current).index_with do |date|
      raw_completed_values[date.to_s].to_f + raw_completed_values[date].to_f
    end

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

class Dashboard::AnalyticsController < Dashboard::BaseController
  def show
    month_start = Date.current.beginning_of_month.beginning_of_day
    month_end = month_start.next_month
    completed_bookings = @business.bookings.completed
    month_bookings = @business.bookings.in_month(month_start)
    @completed_value_month = month_bookings.completed.sum(:total_amount)
    @bookings_month = month_bookings.count
    first_bookings = @business.bookings.select(:user_id).group(:user_id)
                             .having("MIN(bookings.start_time) >= ? AND MIN(bookings.start_time) < ?", month_start, month_end)
    @new_customers = User.where(id: first_bookings).count
    @rating = @business.avg_rating

    paid_attempts = PaymentAttempt.paid.production_payments.joins(:booking)
                                   .where(bookings: { business_id: @business.id })
                                   .where(settled_at: Date.current.beginning_of_month.beginning_of_day..Time.current)
    @online_payments_month = paid_attempts.distinct.count(:booking_id)
    @online_collected_month = paid_attempts.sum(:amount)

    # Nilai booking selesai 30 hari terakhir (fill gap manual)
    from = 29.days.ago.to_date
    raw_completed_values = completed_bookings.unscope(:order)
                                            .where(start_time: from.beginning_of_day..Date.current.end_of_day)
                                            .group("DATE(bookings.start_time AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Jakarta')")
                                            .sum(:total_amount)
    @daily_completed_values = (from..Date.current).index_with do |date|
      raw_completed_values[date.to_s].to_f + raw_completed_values[date].to_f
    end

    # Layanan terpopuler bulan ini
    @top_services = BookingItem.joins(:booking)
                               .merge(month_bookings.where.not(status: :cancelled))
                               .joins(:service)
                               .group("services.name")
                               .count
                               .sort_by { |_, v| -v }
                               .first(5)
  end
end

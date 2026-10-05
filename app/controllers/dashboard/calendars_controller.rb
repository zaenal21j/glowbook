class Dashboard::CalendarsController < Dashboard::BaseController
  DAY_START = 9
  DAY_END = 21

  def show
    @view = %w[hari minggu bulan].include?(params[:view]) ? params[:view] : "hari"
    @date = params[:date].present? ? (Date.parse(params[:date]) rescue Date.current) : Date.current
    @staff_members = @business.staff.ordered

    case @view
    when "hari"
      @day_bookings = @business.bookings.on_date(@date)
                               .where(status: %w[pending confirmed completed])
                               .includes(:user, booking_items: [:service, :staff])
    when "minggu"
      @week_start = @date.beginning_of_week
      @week_bookings = @business.bookings.for_week(@week_start)
                                .where(status: %w[pending confirmed completed])
                                .includes(:user, booking_items: [:service, :staff])
                                .group_by { |b| b.start_time.to_date }
    when "bulan"
      @month_bookings = @business.bookings.in_month(@date.beginning_of_month)
                                 .where(status: %w[pending confirmed completed])
                                 .includes(:user, booking_items: [:service])
                                 .group_by { |b| b.start_time.to_date }
    end
  end
end

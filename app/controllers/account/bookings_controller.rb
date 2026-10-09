class Account::BookingsController < Account::BaseController
  def index
    case params[:tab]
    when "selesai"
      @bookings = current_user.bookings.past
    when "dibatalkan"
      @bookings = current_user.bookings.where(status: %i[cancelled no_show])
    else
      @tab = "akan-datang"
      @bookings = current_user.bookings.upcoming
    end
    @tab ||= params[:tab]
    order = @tab == "akan-datang" ? :asc : :desc
    @bookings = paginate(@bookings.includes(business: :city, booking_items: [:service, :staff]).order(start_time: order))
  end
end

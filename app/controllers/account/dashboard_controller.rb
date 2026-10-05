class Account::DashboardController < Account::BaseController
  def show
    @upcoming = current_user.bookings.upcoming.includes(business: :city, booking_items: [:service, :staff]).limit(3)
    @total_bookings = current_user.bookings.count
    @completed_count = current_user.bookings.completed.count
    @favorites_count = current_user.favorites.count
    @reviews_count = current_user.reviews.count
  end
end

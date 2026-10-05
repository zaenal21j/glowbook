class Admin::BusinessesController < Admin::BaseController
  def index
    scope = case params[:status]
            when "active" then Business.active
            when "pending" then Business.pending
            when "suspended" then Business.suspended
            else Business.all
            end

    scope = scope.merge(Business.search(params[:q])) if params[:q].present?
    @businesses = scope.includes(:city, :owner).order(created_at: :desc).limit(200)
    @counts = { all: Business.count, active: Business.active.count, pending: Business.pending.count, suspended: Business.suspended.count }
  end

  def show
    @business = Business.find(params[:id])
    @services = @business.services.ordered
    @staff = @business.staff.ordered
    @bookings = @business.bookings.order(start_time: :desc).limit(15).includes(:user, booking_items: [:service])
    @reviews = @business.reviews.recent.limit(10).includes(:user)
  end

  def destroy
    business = Business.find(params[:id])
    business.update!(status: :suspended)
    redirect_to admin_businesses_path, notice: "Bisnis \"#{business.name}\" dinonaktifkan."
  end
end

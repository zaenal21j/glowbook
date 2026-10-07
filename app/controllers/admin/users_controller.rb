class Admin::UsersController < Admin::BaseController
  def index
    scope = case params[:role]
    when "customer" then User.customers
    when "owner" then User.owners
    when "admin" then User.where(role: :admin)
    else User.all
    end

    scope = scope.where("name ILIKE :q OR email ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
    @users = paginate(scope.order(created_at: :desc))
    @counts = { all: User.count, customer: User.customers.count, owner: User.owners.count, admin: User.where(role: :admin).count }
  end

  def show
    @user = User.find(params[:id])
    @bookings = @user.bookings.order(start_time: :desc).limit(20).includes(:business, booking_items: [ :service ])
  end

  def destroy
    user = User.find(params[:id])
    if user == current_user
      redirect_to admin_users_path, alert: "Anda tidak bisa menghapus akun sendiri."
    else
      user.destroy
      redirect_to admin_users_path, notice: "Pengguna dihapus."
    end
  end
end

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
    elsif user.admin?
      redirect_to admin_users_path, alert: "Akun admin tidak dapat dihapus dari panel ini."
    elsif user.businesses.exists? || user.staff_member.present? || user.bookings.exists? ||
          user.reviews.exists? || user.conversations.exists? || user.chat_messages.exists?
      redirect_to admin_users_path, alert: "Pengguna ini memiliki bisnis, riwayat, atau pesan yang harus disimpan."
    else
      user.destroy!
      redirect_to admin_users_path, notice: "Pengguna dihapus."
    end
  rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::RecordNotDestroyed
    redirect_to admin_users_path, alert: "Pengguna tidak dapat dihapus karena masih memiliki data terkait."
  end
end

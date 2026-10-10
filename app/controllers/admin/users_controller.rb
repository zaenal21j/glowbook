class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: %i[show edit update]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    assign_requested_role
    if @user.save
      redirect_to admin_user_path(@user), notice: I18n.t("admin.user_management.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    attributes = user_params
    if attributes[:password].blank? && attributes[:password_confirmation].blank?
      attributes = attributes.except(:password, :password_confirmation)
    end
    @user.with_lock do
      @user.assign_attributes(attributes)
      assign_requested_role
      if @user.role_changed? && (@user.role_was == "admin" || @user == current_user || @user.businesses.exists? || @user.staff_member.present?)
        @user.errors.add(:role, I18n.t("admin.user_management.role_locked"))
        return render :edit, status: :unprocessable_content
      end
      if @user.provider.present? && @user.email_changed?
        @user.errors.add(:email, I18n.t("admin.user_management.oauth_email_locked"))
        return render :edit, status: :unprocessable_content
      end
      if @user.save
        bypass_sign_in(@user) if @user == current_user
        redirect_to admin_user_path(@user), notice: I18n.t("admin.user_management.updated")
      else
        render :edit, status: :unprocessable_content
      end
    end
  end

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
    @bookings = paginate(@user.bookings.order(start_time: :desc).includes(:business, booking_items: [ :service ]))
  end

  def destroy
    user = User.find(params[:id])
    if user == current_user
      redirect_to admin_users_path, alert: I18n.t("admin.users.errors.delete_self")
    elsif user.admin?
      redirect_to admin_users_path, alert: I18n.t("admin.users.errors.delete_admin")
    elsif user.has_retained_records?
      redirect_to admin_users_path, alert: I18n.t("admin.users.errors.related_data")
    else
      user.destroy!
      redirect_to admin_users_path, notice: I18n.t("admin.users.deleted")
    end
  rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::RecordNotDestroyed
    redirect_to admin_users_path, alert: I18n.t("admin.users.errors.restricted")
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :phone, :password, :password_confirmation)
  end

  def assign_requested_role
    return unless params[:user].key?(:role)

    requested_role = params[:user][:role]
    @user.role = User.roles.key?(requested_role) ? requested_role : nil
  end
end

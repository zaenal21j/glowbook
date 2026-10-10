class Admin::BusinessesController < Admin::BaseController
  def new
    @business = Business.new(status: :pending)
  end

  def create
    @business = Business.new(business_params.except(:category_ids))
    @business.status = :pending
    @business.slug = "#{@business.name.to_s.parameterize.presence || 'business'}-#{SecureRandom.hex(4)}"
    return render :new, status: :unprocessable_content unless assign_categories
    owner = @business.owner
    unless owner && (owner.customer? || owner.role == "business_owner") && !owner.businesses.exists?
      @business.errors.add(:owner, I18n.t("admin.management.owner_required"))
      return render :new, status: :unprocessable_content
    end
    Business.transaction do
      owner.lock!
      if owner.businesses.exists?
        @business.errors.add(:owner, I18n.t("admin.management.owner_required"))
        return render :new, status: :unprocessable_content
      end
      @business.save!
      (0..6).each { |day| @business.business_hours.create!(weekday: day, open_minute: 540, close_minute: 1020, closed: true) }
      owner.update!(role: :business_owner) if owner.customer?
    end
      redirect_to admin_business_path(@business.id), notice: I18n.t("admin.management.created")
  rescue ActiveRecord::RecordInvalid => error
      @business.errors.add(:base, error.record.errors.full_messages.to_sentence) unless error.record == @business
      render :new, status: :unprocessable_content
  end

  def edit
    @business = Business.find(params[:id])
  end

  def update
    @business = Business.find(params[:id])
    # Ownership changes need a separate transfer workflow; preserve existing ownership.
    @business.assign_attributes(business_params.except(:owner_id, :category_ids))
    return render :edit, status: :unprocessable_content unless assign_categories
    if @business.save
      redirect_to admin_business_path(@business.id), notice: I18n.t("admin.management.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def index
    scope = case params[:status]
    when "active" then Business.active
    when "pending" then Business.pending
    when "suspended" then Business.suspended
    else Business.all
    end

    scope = scope.merge(Business.search(params[:q])) if params[:q].present?
    @businesses = paginate(scope.includes(:city, :owner).order(created_at: :desc))
    @counts = { all: Business.count, active: Business.active.count, pending: Business.pending.count, suspended: Business.suspended.count }
  end

  def show
    @business = Business.find(params[:id])
    @services = @business.services.ordered
    @staff = @business.staff.ordered
    @bookings = @business.bookings.order(start_time: :desc).limit(15).includes(:user, booking_items: [ :service ])
    @reviews = @business.reviews.recent.limit(10).includes(:user)
  end

  def destroy
    business = Business.find(params[:id])
    business.update!(status: :suspended)
    redirect_to admin_businesses_path, notice: I18n.t("admin.businesses.flash.suspended", name: business.name)
  end

  def activate
    business = Business.pending.find(params[:id])
    business.update!(status: :active)
    redirect_to admin_businesses_path(status: "pending"), notice: I18n.t("admin.businesses.flash.approved", name: business.name)
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_businesses_path(status: "pending"), alert: I18n.t("admin.businesses.flash.unavailable")
  end

  def reactivate
    business = Business.suspended.find(params[:id])
    business.update!(status: :active)
    redirect_to admin_businesses_path(status: "suspended"), notice: I18n.t("admin.businesses.flash.reactivated", name: business.name)
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_businesses_path(status: "suspended"), alert: I18n.t("admin.businesses.flash.unavailable")
  end

  private

  def business_params
    params.require(:business).permit(:name, :owner_id, :city_id, :address, :phone, :description, :latitude, :longitude, category_ids: [])
  end

  def assign_categories
    ids = Array(business_params[:category_ids]).reject(&:blank?).map(&:to_s).uniq
    categories = Category.where(id: ids)
    if categories.empty? || categories.size != ids.size
      @business.errors.add(:categories, I18n.t("business_signup.errors.choose_category"))
      return false
    end
    # Assign only after the business validates so invalid profile edits cannot save category changes.
    return false unless @business.valid?
    @business.categories = categories
    true
  end
end

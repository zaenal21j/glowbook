class Dashboard::StaffsController < Dashboard::BaseController
  def index
    @staff = paginate(@business.staff.ordered.includes(:services, :staff_schedules))
  end

  def new
    @staff_member = @business.staff.build
  end

  def create
    @staff_member = @business.staff.build(staff_params)

    if @staff_member.save
      redirect_to dashboard_staff_availability_path(@staff_member), notice: t("business_management.staff.flash.created", name: @staff_member.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @staff_member = @business.staff.find(params[:id])
  end

  def update
    @staff_member = @business.staff.find(params[:id])

    if @staff_member.update(staff_params)
      redirect_to dashboard_staffs_path, notice: t("business_management.staff.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @staff_member = @business.staff.find(params[:id])
    if @staff_member.destroy
      redirect_to dashboard_staffs_path, notice: t("business_management.staff.flash.deleted")
    else
      redirect_to dashboard_staffs_path, alert: t("scheduling.errors.staff_in_use")
    end
  end

  private

  def staff_params
    permitted = params.require(:staff).permit(:name, :title, :bio, :active, service_ids: [])
    if permitted.key?(:service_ids)
      ids = permitted[:service_ids].reject(&:blank?).map(&:to_s).uniq
      valid_ids = @business.services.where(id: ids).ids.map(&:to_s)
      raise ActiveRecord::RecordNotFound unless (ids - valid_ids).empty?
    end
    permitted
  end
end

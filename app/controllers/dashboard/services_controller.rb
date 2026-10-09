class Dashboard::ServicesController < Dashboard::BaseController
  def index
    @services = paginate(@business.services.includes(:category, :staff).ordered)
    @categories = Category.ordered
  end

  def new
    @service = @business.services.build
  end

  def create
    @service = @business.services.build(service_params)

    if @service.save
      redirect_to dashboard_services_path, notice: t("business_management.services.flash.created", name: @service.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @service = @business.services.find(params[:id])
  end

  def update
    @service = @business.services.find(params[:id])

    if @service.update(service_params)
      redirect_to dashboard_services_path, notice: t("business_management.services.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @service = @business.services.find(params[:id])
    if @service.destroy
      redirect_to dashboard_services_path, notice: t("business_management.services.flash.deleted")
    else
      redirect_to dashboard_services_path, alert: t("scheduling.errors.service_in_use")
    end
  end

  private

  def service_params
    params.require(:service).permit(:name, :description, :price, :duration_minutes, :category_id, :active, :position)
  end
end

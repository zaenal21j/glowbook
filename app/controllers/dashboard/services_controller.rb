class Dashboard::ServicesController < Dashboard::BaseController
  def index
    @services = @business.services.includes(:category, :staff).ordered
    @categories = Category.ordered
  end

  def new
    @service = @business.services.build
  end

  def create
    @service = @business.services.build(service_params)

    if @service.save
      redirect_to dashboard_services_path, notice: "Layanan \"#{@service.name}\" dibuat."
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
      redirect_to dashboard_services_path, notice: "Layanan diperbarui."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @service = @business.services.find(params[:id])
    @service.destroy
    redirect_to dashboard_services_path, notice: "Layanan dihapus."
  end

  private

  def service_params
    params.require(:service).permit(:name, :description, :price, :duration_minutes, :category_id, :active, :position)
  end
end

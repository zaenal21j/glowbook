class Dashboard::StaffsController < Dashboard::BaseController
  def index
    @staff = @business.staff.ordered.includes(:services, :staff_schedules)
  end

  def new
    @staff_member = @business.staff.build
  end

  def create
    @staff_member = @business.staff.build(staff_params)

    if @staff_member.save
      redirect_to dashboard_staffs_path, notice: "Staff \"#{@staff_member.name}\" ditambahkan."
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
      redirect_to dashboard_staffs_path, notice: "Data staff diperbarui."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @staff_member = @business.staff.find(params[:id])
    @staff_member.destroy
    redirect_to dashboard_staffs_path, notice: "Staff dihapus."
  end

  private

  def staff_params
    params.require(:staff).permit(:name, :title, :bio, :active, service_ids: [])
  end
end

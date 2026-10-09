class Dashboard::ProfilesController < Dashboard::BaseController
  def show
    @business_hours = @business.business_hours.order(:weekday)
  end

  def update
    if @business.update(profile_params)
      redirect_to dashboard_profile_path, notice: "Profil bisnis diperbarui."
    else
      @business_hours = @business.business_hours.order(:weekday)
      render :show, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    permitted = %i[name address phone description latitude longitude]
    permitted << { cover_image: [], logo_image: [] }
    params.require(:business).permit(*permitted)
  end
end

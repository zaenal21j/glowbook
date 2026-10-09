class Dashboard::ProfilesController < Dashboard::BaseController
  def show
    prepare_hours
  end

  def update
    if @business.update(profile_params)
      redirect_to dashboard_profile_path, notice: t("alerts.business.profile_updated")
    else
      prepare_hours
      render :show, status: :unprocessable_entity
    end
  end

  private

  def prepare_hours
    existing_days = @business.business_hours.map(&:weekday)
    (0..6).each do |weekday|
      next if existing_days.include?(weekday)

      @business.business_hours.build(weekday: weekday, open_minute: 540, close_minute: 1020, closed: true)
    end
  end

  def profile_params
    permitted = %i[name address phone description latitude longitude]
    permitted << { business_hours_attributes: %i[id weekday open_minute close_minute closed] }
    params.require(:business).permit(*permitted)
  end
end

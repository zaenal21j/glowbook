class Admin::SettingsController < Admin::BaseController
  def show
    @settings = PlatformSetting.current
    @online_payments_enabled = Rails.configuration.x.midtrans_enabled
  end

  def update
    @settings = PlatformSetting.current

    if @settings.update(settings_params)
      redirect_to admin_settings_path, notice: t("alerts.admin.settings_saved")
    else
      @online_payments_enabled = Rails.configuration.x.midtrans_enabled
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:platform_setting).permit(:business_registration_open, :commission_percentage)
  end
end

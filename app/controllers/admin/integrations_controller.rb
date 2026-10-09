class Admin::IntegrationsController < Admin::BaseController
  def index
    load_integrations
  end

  def update
    return head :not_found unless IntegrationSetting::PROVIDERS.include?(params[:provider])

    integration = IntegrationSetting.effective(params[:provider])
    fields = IntegrationSetting::FIELDS.fetch(params[:provider])
    attributes = params.require(:integration_setting).permit(:enabled, :clear_secret, settings: fields)
    if integration.update_configuration(attributes)
      redirect_to admin_integrations_path, notice: t("integrations.saved")
    else
      load_integrations
      @integrations[integration.provider] = integration
      render :index, status: :unprocessable_content
    end
  end

  private

  def load_integrations
    @integrations = IntegrationSetting::PROVIDERS.index_with do |provider|
      IntegrationSetting.effective(provider).tap(&:ready?)
    end
  end
end

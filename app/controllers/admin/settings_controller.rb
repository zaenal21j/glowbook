class Admin::SettingsController < Admin::BaseController
  def show
    @facebook_enabled = Rails.application.config.x.facebook_oauth_enabled
    @user_count = User.count
    @business_count = Business.count
    @storage_service = Rails.application.config.active_storage.service.to_s
  end
end

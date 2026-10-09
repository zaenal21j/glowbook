class Dashboard::BaseController < ApplicationController
  include Paginatable

  layout "dashboard"
  before_action :require_business_owner!
  before_action :set_current_business

  helper_method :current_business

  private

  def set_current_business
    @business = current_business
    redirect_to root_path, alert: t("alerts.access.business_unregistered") if @business.nil?
  end

  def current_business
    @current_business ||= current_user.businesses.first || Staff.active.find_by(user: current_user)&.business
  end
end

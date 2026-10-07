class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :current_business

  protected

  def after_sign_in_path_for(resource)
    return stored_location_for(resource) || admin_root_path if resource.admin?
    return stored_location_for(resource) || dashboard_root_path if resource.business_owner? && resource.businesses.exists?
    return stored_location_for(resource) || dashboard_root_path if resource.staff_member&.active?

    stored_location_for(resource) || account_root_path
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :phone])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :phone, :remote_avatar_url])
  end

  private

  def require_customer!
    unless user_signed_in?
      redirect_to login_path, alert: "Silakan masuk untuk melanjutkan."
      return
    end
  end

  def require_business_owner!
    unless user_signed_in?
      redirect_to login_path, alert: "Silakan masuk untuk melanjutkan."
      return
    end

    unless current_user.business_owner? || current_user.staff_member&.business
      redirect_to root_path, alert: "Anda tidak memiliki akses ke dashboard bisnis."
    end
  end

  def require_admin!
    unless user_signed_in?
      redirect_to login_path, alert: "Silakan masuk untuk melanjutkan."
      return
    end

    unless current_user.admin?
      redirect_to root_path, alert: "Hanya admin yang dapat mengakses halaman ini."
    end
  end

  def owned_business
    if current_user.admin?
      Business.order(:name)
    else
      Business.where(owner: current_user)
              .or(Business.where(id: current_user.staff_member&.business_id))
    end
  end

  def current_business
    @current_business ||= owned_business.first
  end

  def staff_for_business!
    @business = Business.find_by(slug: params[:slug])
    render_not_found unless @business
  end
end

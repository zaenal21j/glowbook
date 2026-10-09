class Users::RegistrationsController < Devise::RegistrationsController
  def destroy
    if current_user.admin? || current_user.has_retained_records?
      return redirect_to account_settings_path, alert: t("alerts.account.deletion_restricted")
    end

    super
  end
end

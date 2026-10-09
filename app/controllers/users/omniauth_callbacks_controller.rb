class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def facebook
    auth = request.env["omniauth.auth"]
    return redirect_to login_path, alert: t("alerts.oauth.facebook_cancelled_or_failed") unless auth

    @user = User.from_facebook(auth)

    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: "Facebook") if is_navigational_format?
    else
      redirect_to new_user_registration_url, alert: t("alerts.oauth.facebook_signin_failed")
    end
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    redirect_to login_path, alert: t("alerts.oauth.facebook_account_conflict")
  end

  def google_oauth2
    auth = request.env["omniauth.auth"]
    return redirect_to login_path, alert: t("integrations.oauth_failed") unless auth

    @user = User.from_google(auth)
    sign_in_and_redirect @user, event: :authentication
    set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
  rescue User::InvalidGoogleIdentity
    redirect_to login_path, alert: t("integrations.google_unverified")
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    redirect_to login_path, alert: t("integrations.account_conflict")
  end

  def failure
    redirect_to login_path, alert: t("integrations.oauth_failed")
  end
end

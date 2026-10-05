class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def facebook
    @user = User.from_facebook(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: "Facebook") if is_navigational_format?
    else
      redirect_to new_user_registration_url, alert: "Gagal masuk dengan Facebook. Coba lagi."
    end
  end

  def failure
    redirect_to login_path, alert: "Login Facebook dibatalkan atau gagal."
  end
end

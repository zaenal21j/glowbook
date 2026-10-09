class Account::PasswordsController < Account::BaseController
  def show
    @user = current_user
  end

  def update
    @user = current_user
    attributes = params.require(:user).permit(:current_password, :password, :password_confirmation)
    if attributes[:password].blank?
      @user.errors.add(:password, :blank)
    elsif @user.update_with_password(attributes)
      bypass_sign_in(@user)
      return redirect_to account_settings_path, status: :see_other, notice: t("account.security.password_updated")
    end

    @user.clean_up_passwords
    render :show, status: :unprocessable_content
  end
end

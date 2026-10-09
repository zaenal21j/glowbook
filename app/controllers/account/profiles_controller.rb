class Account::ProfilesController < Account::BaseController
  def show
    @user = current_user
  end

  def update
    @user = current_user
    attributes = profile_params
    changing_email = attributes[:email].present? && attributes[:email].strip.downcase != @user.email
    saved = if changing_email
      @user.update_with_password(attributes)
    else
      @user.update(attributes.except(:current_password))
    end
    if saved
      redirect_to account_profile_path, notice: t("alerts.account.profile_updated")
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :phone, :email, :current_password)
  end
end

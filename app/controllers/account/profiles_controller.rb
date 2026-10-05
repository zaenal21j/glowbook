class Account::ProfilesController < Account::BaseController
  def show
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(profile_params)
      redirect_to account_profile_path, notice: "Profil berhasil diperbarui."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :phone, :email)
  end
end

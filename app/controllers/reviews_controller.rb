class ReviewsController < ApplicationController
  before_action :set_business, only: %i[new create]
  before_action :authenticate_user!, only: %i[new create]
  before_action :require_completed_visit!, only: %i[new create]

  def new
    @review = @business.reviews.new
  end

  def create
    @review = current_user.reviews.new(review_params.merge(business: @business))

    if @review.save
      redirect_to business_detail_path(@business.slug), notice: t("alerts.reviews.submitted")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_business
    @business = Business.active.find_by!(slug: params[:business_id] || params[:slug])
  end

  def review_params
    params.require(:review).permit(:rating, :comment)
  end

  def require_completed_visit!
    owner_or_staff = @business.owner_id == current_user.id || @business.staff.exists?(user_id: current_user.id)
    return if !owner_or_staff && current_user.bookings.where(business: @business, status: :completed).exists?

    redirect_to business_detail_path(@business.slug), alert: t("alerts.reviews.completed_visit_required")
  end
end

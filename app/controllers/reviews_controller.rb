class ReviewsController < ApplicationController
  before_action :set_business, only: %i[new create]
  before_action :authenticate_user!, only: %i[new create]

  def new
    @review = @business.reviews.new
  end

  def create
    @review = current_user.reviews.new(review_params.merge(business: @business))

    if @review.save
      redirect_to business_detail_path(@business.slug), notice: "Ulasan berhasil dikirim."
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
end

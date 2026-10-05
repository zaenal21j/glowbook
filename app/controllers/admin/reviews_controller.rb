class Admin::ReviewsController < Admin::BaseController
  def index
    scope = case params[:rating]
            when "5", "4", "3", "2", "1" then Review.where(rating: params[:rating].to_i)
            else Review.all
            end
    @reviews = scope.recent.includes(:user, :business).limit(200)
    @avg_rating = Review.average(:rating)&.round(2)
  end

  def destroy
    review = Review.find(params[:id])
    business = review.business
    review.destroy
    redirect_to admin_reviews_path, notice: "Ulasan dari #{business.name} dihapus."
  end
end

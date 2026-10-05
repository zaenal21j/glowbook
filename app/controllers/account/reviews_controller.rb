class Account::ReviewsController < Account::BaseController
  def index
    @reviews = current_user.reviews.includes(:business).recent
  end
end

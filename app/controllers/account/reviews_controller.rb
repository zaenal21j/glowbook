class Account::ReviewsController < Account::BaseController
  def index
    @reviews = paginate(current_user.reviews.includes(:business).recent)
  end
end

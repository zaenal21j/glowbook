class Account::FavoritesController < Account::BaseController
  def index
    @businesses = current_user.favorites
                              .includes(business: [:city, :categories, :services, :promotions])
                              .map(&:business)
  end
end

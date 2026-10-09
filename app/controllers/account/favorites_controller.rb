class Account::FavoritesController < Account::BaseController
  def index
    @favorites = paginate(current_user.favorites
                                      .includes(business: [:city, :categories, :services, :promotions])
                                      .order(created_at: :desc))
    @businesses = @favorites.map(&:business)
  end
end

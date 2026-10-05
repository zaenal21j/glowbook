class SearchesController < ApplicationController
  PER_PAGE = 12

  def index
    @active_city = City.find_by(slug: params[:city]) if params[:city].present?
    @sort = %w[rating price].include?(params[:sort]) ? params[:sort] : "rating"

    scope = Business.active.includes(:city, :categories, :services, :promotions)
    scope = scope.in_city(params[:city]) if params[:city].present?
    scope = scope.search(params[:q]) if params[:q].present?
    scope = scope.min_rating(params[:min_rating]) if params[:min_rating].present?
    scope = scope.has_promo if params[:promo] == "1"
    scope = scope.open_today if params[:open_today] == "1"

    if params[:categories].present?
      category_slugs = Array(params[:categories]).reject(&:blank?)
      scope = scope.with_any_category(category_slugs) if category_slugs.any?
    end

    if params[:min_price].present? || params[:max_price].present?
      scope = scope.price_between(params[:min_price], params[:max_price])
    end

    scope = @sort == "price" ? scope.by_min_price : scope.by_rating

    @page = [params[:page].to_i, 1].max
    @total_count = scope.count
    @total_pages = [(@total_count.to_f / PER_PAGE).ceil, 1].max
    @businesses = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end
end

class SearchesController < ApplicationController
  PER_PAGE = 12
  NEARBY_ORIGIN_TTL = 30.minutes

  def index
    @active_city = City.find_by(slug: params[:city]) if params[:city].present?
    @sort = %w[rating price nearby].include?(params[:sort]) ? params[:sort] : "rating"

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

    @total_count = scope.count
    @total_pages = [(@total_count.to_f / PER_PAGE).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @total_pages)
    case @sort
    when "price"
      scope = scope.by_min_price
      session.delete(:nearby_search_origin)
    when "nearby"
      @nearby_origin = valid_nearby_origin
      @nearby_active = @nearby_origin.present?
      scope = @nearby_active ? scope.near_point(@nearby_origin[:latitude], @nearby_origin[:longitude]) : scope.by_rating
    else
      scope = scope.by_rating
      session.delete(:nearby_search_origin)
    end
    @businesses = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def nearby
    latitude = Float(params[:latitude], exception: false)
    longitude = Float(params[:longitude], exception: false)
    unless latitude && longitude && (-90..90).cover?(latitude) && (-180..180).cover?(longitude)
      return redirect_to search_path(search_filters), alert: t("alerts.search.invalid_location")
    end

    session[:nearby_search_origin] = {
      "latitude" => latitude.round(6),
      "longitude" => longitude.round(6),
      "created_at" => Time.current.to_i
    }
    redirect_to search_path(search_filters.merge(sort: "nearby", page: 1))
  end

  private

  def search_filters
    params.permit(:q, :city, :min_price, :max_price, :min_rating, :open_today, :promo, categories: []).to_h
  end

  def valid_nearby_origin
    origin = session[:nearby_search_origin]
    return unless origin.is_a?(Hash)

    created_at = Integer(origin["created_at"], exception: false)
    if created_at.nil? || created_at < NEARBY_ORIGIN_TTL.ago.to_i
      session.delete(:nearby_search_origin)
      return
    end

    latitude = Float(origin["latitude"], exception: false)
    longitude = Float(origin["longitude"], exception: false)
    return unless latitude && longitude && (-90..90).cover?(latitude) && (-180..180).cover?(longitude)

    { latitude: latitude, longitude: longitude }
  end
end

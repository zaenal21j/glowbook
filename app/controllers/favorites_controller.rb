class FavoritesController < ApplicationController
  before_action :authenticate_user!

  def create
    business = Business.active.find_by!(slug: params[:slug])
    current_user.favorites.find_or_create_by!(business: business)
    redirect_back fallback_location: business_detail_path(business.slug), status: :see_other
  rescue ActiveRecord::RecordNotUnique
    redirect_back fallback_location: business_detail_path(business.slug), status: :see_other
  end

  def destroy
    business = Business.find_by!(slug: params[:slug])
    current_user.favorites.find_by(business: business)&.destroy
    redirect_back fallback_location: business_detail_path(business.slug), status: :see_other
  end

  # Customer dashboard listing
  def index
    @favorites = current_user.favorites.recent.includes(business: %i[city categories])
    render "account/favorites/index"
  end
end

class FavoritesController < ApplicationController
  before_action :authenticate_user!

  def create
    business = Business.find_by!(slug: params[:slug])
    favorite = current_user.favorites.find_or_create_by!(business: business)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: business_detail_path(business.slug) }
    end
  end

  def destroy
    business = Business.find_by!(slug: params[:slug])
    current_user.favorites.find_by(business: business)&.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: business_detail_path(business.slug) }
    end
  end

  # Customer dashboard listing
  def index
    @favorites = current_user.favorites.recent.includes(business: %i[city categories])
    render "account/favorites/index"
  end
end

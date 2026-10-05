class BusinessesController < ApplicationController
  before_action :set_business

  def show
    @tab = "tentang"
    @reviews = @business.reviews.recent.includes(:user).limit(6)
    @services = @business.services.active.ordered.includes(:category).limit(6)
    @staff = @business.staff.ordered.limit(6)
    @gallery = @business.business_galleries.order(:position)
    @promotions = @business.active_promotions
  end

  def tab
    @tab = %w[tentang layanan staff ulasan lokasi].include?(params[:tab]) ? params[:tab] : "tentang"
    case @tab
    when "layanan"
      @services = @business.services.active.ordered.includes(:category)
    when "staff"
      @staff = @business.staff.ordered
    when "ulasan"
      @reviews = @business.reviews.recent.includes(:user)
    end
    render partial: "businesses/tab_content", locals: { business: @business }
  end

  private

  def set_business
    @business = Business.active.find_by!(slug: params[:slug])
  end
end

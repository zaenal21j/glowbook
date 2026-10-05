class HomeController < ApplicationController
  def index
    @categories = Category.where(is_popular: true).order(:position).limit(10)
    @featured_city = City.find_by(slug: "jakarta") || City.ordered.first
    @featured_businesses = Business.active
                                   .in_city(@featured_city.slug)
                                   .includes(:city, :categories, :services, :promotions)
                                   .order(avg_rating: :desc)
                                   .limit(4)
    @recommended_businesses = Business.active
                                      .includes(:city, :categories, :services, :promotions)
                                      .where.not(id: @featured_businesses.ids)
                                      .order(avg_rating: :desc)
                                      .limit(8)
  end
end

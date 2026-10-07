class PagesController < ApplicationController
  def business
    # Untuk Bisnis landing page
  end

  def business_signup
    @cities = City.ordered
    @categories = Category.ordered
    @business = Business.new
  end
end

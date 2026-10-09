class CategoriesController < ApplicationController
  def show
    @category = Category.find_by!(slug: params[:slug])
    redirect_to search_path(categories: [ @category.slug ])
  end
end

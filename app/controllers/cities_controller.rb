class CitiesController < SearchesController
  def show
    params[:city] = params[:slug]
    index
    render "searches/index"
  end
end

module Paginatable
  DEFAULT_PER_PAGE = 25

  private

  def paginate(scope, per_page: DEFAULT_PER_PAGE, total_count: nil)
    count = total_count.nil? ? scope.count : total_count
    @total_count = count.is_a?(Hash) ? count.size : count
    @per_page = per_page
    @total_pages = [ (@total_count.to_f / @per_page).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @total_pages)

    scope.limit(@per_page).offset((@page - 1) * @per_page)
  end
end

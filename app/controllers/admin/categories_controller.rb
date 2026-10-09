class Admin::CategoriesController < Admin::BaseController
  before_action :set_category, only: %i[edit update destroy toggle_popular]

  def index
    load_categories
  end

  def create
    @category = Category.new(category_params)
    @category.slug = params[:category][:slug].presence || @category.name.to_s.parameterize

    if @category.save
      redirect_to admin_categories_path, notice: I18n.t("admin.categories.flash.created", name: @category.name)
    else
      load_categories(category: @category)
      render :index, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @category.update(category_params)
      redirect_to admin_categories_path, notice: I18n.t("admin.categories.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @category.services.exists?
      redirect_to admin_categories_path, alert: I18n.t("admin.categories.errors.in_use", count: @category.services.count)
    else
      @category.destroy
      redirect_to admin_categories_path, notice: I18n.t("admin.categories.flash.deleted")
    end
  end

  def toggle_popular
    @category.update!(is_popular: !@category.is_popular)
    state = @category.is_popular ? I18n.t("admin.categories.flash.marked") : I18n.t("admin.categories.flash.unmarked")
    redirect_to admin_categories_path, notice: I18n.t("admin.categories.flash.popular", name: @category.name, state: state)
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def load_categories(category: nil)
    scope = Category.ordered
                    .left_joins(:businesses)
                    .select("categories.*, COUNT(DISTINCT business_categories.business_id) AS businesses_count")
                    .group("categories.id")
    total_count = scope.except(:select, :group, :order).distinct.count(:id)
    @categories = paginate(scope, total_count: total_count)
    @category = category || Category.new
  end

  def category_params
    params.require(:category).permit(:name, :slug, :tagline, :icon_name, :position)
  end
end

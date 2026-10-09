class Dashboard::PromotionsController < Dashboard::BaseController
  def index
    @promotions = paginate(@business.promotions.order(created_at: :desc))
  end

  def new
    @promotion = @business.promotions.build
  end

  def create
    @promotion = @business.promotions.build(promotion_params)

    if @promotion.save
      redirect_to dashboard_promotions_path, notice: t("business_management.promotions.flash.created", name: @promotion.title)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @promotion = @business.promotions.find(params[:id])
  end

  def update
    @promotion = @business.promotions.find(params[:id])

    if @promotion.update(promotion_params)
      redirect_to dashboard_promotions_path, notice: t("business_management.promotions.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @promotion = @business.promotions.find(params[:id])
    @promotion.destroy
    redirect_to dashboard_promotions_path, notice: t("business_management.promotions.flash.deleted")
  end

  def toggle
    @promotion = @business.promotions.find(params[:id])
    @promotion.update!(active: !@promotion.active)
    redirect_to dashboard_promotions_path, notice: t(@promotion.active? ? "business_management.promotions.flash.enabled" : "business_management.promotions.flash.disabled")
  end

  private

  def promotion_params
    params.require(:promotion).permit(:title, :code, :discount_percent, :starts_at, :ends_at, :active)
  end
end

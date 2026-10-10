class Admin::PromotionsController < Admin::BaseController
  def new
    @promotion = Promotion.new(active: false)
  end

  def create
    @promotion = Promotion.new(promotion_params)
    if @promotion.save
      redirect_to admin_promotions_path, notice: I18n.t("admin.management.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @promotion = Promotion.find(params[:id])
  end

  def update
    @promotion = Promotion.find(params[:id])
    if @promotion.update(promotion_params.except(:business_id))
      redirect_to admin_promotions_path, notice: I18n.t("admin.management.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def index
    scope = case params[:state]
    when "active" then Promotion.active_now
    when "inactive" then Promotion.where(active: false)
    else Promotion.all
    end
    @promotions = paginate(scope.includes(:business).order(created_at: :desc))
  end

  def destroy
    promo = Promotion.find(params[:id])
    promo.destroy
    redirect_to admin_promotions_path, notice: I18n.t("admin.promotions.flash_deleted", title: promo.title)
  end

  private

  def promotion_params
    params.require(:promotion).permit(:business_id, :title, :code, :discount_percent, :starts_at, :ends_at, :active)
  end
end

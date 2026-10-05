class Admin::PromotionsController < Admin::BaseController
  def index
    scope = case params[:state]
            when "active" then Promotion.active_now
            when "inactive" then Promotion.where(active: false)
            else Promotion.all
            end
    @promotions = scope.includes(:business).order(created_at: :desc).limit(200)
  end

  def destroy
    promo = Promotion.find(params[:id])
    promo.destroy
    redirect_to admin_promotions_path, notice: "Promosi \"#{promo.title}\" dihapus."
  end
end

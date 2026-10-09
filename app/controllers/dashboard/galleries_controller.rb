class Dashboard::GalleriesController < Dashboard::BaseController
  MAX_IMAGES = 6

  def index
    load_galleries
    @gallery = @business.business_galleries.build
  end

  def create
    if @business.business_galleries.count >= MAX_IMAGES
      return redirect_to dashboard_galleries_path, alert: t("alerts.gallery.limit_reached", count: MAX_IMAGES)
    end

    @gallery = @business.business_galleries.build(gallery_params)
    @gallery.position = @business.business_galleries.maximum(:position).to_i + 1

    if @gallery.save
      redirect_to dashboard_galleries_path, notice: t("alerts.gallery.photo_added")
    else
      load_galleries
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @business.business_galleries.find(params[:id]).destroy!
    redirect_to dashboard_galleries_path, notice: t("alerts.gallery.photo_deleted")
  end

  private

  def gallery_params
    params.require(:business_gallery).permit(:image, :caption)
  end

  def load_galleries
    @galleries = @business.business_galleries.with_attached_image.order(:position, :id)
  end
end

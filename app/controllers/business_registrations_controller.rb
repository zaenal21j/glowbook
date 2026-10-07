class BusinessRegistrationsController < ApplicationController
  before_action :authenticate_user!

  def create
    unless current_user.customer? || current_user.business_owner?
      return redirect_to registrasi_bisnis_path, alert: "Akun ini tidak dapat mendaftarkan bisnis."
    end

    if current_user.businesses.exists?
      return redirect_to dashboard_root_path, notice: "Akun Anda sudah memiliki bisnis."
    end

    @cities = City.ordered
    @categories = Category.ordered
    @business = current_user.businesses.build(business_params.except(:category_ids))
    category_ids = Array(business_params[:category_ids]).reject(&:blank?).map(&:to_i).uniq
    categories = Category.where(id: category_ids)

    if categories.empty? || categories.size != category_ids.size
      @business.errors.add(:categories, "pilih minimal satu kategori yang tersedia")
      return render "pages/business_signup", status: :unprocessable_entity
    end

    @business.slug = unique_slug(@business.name)
    @business.status = :pending

    Business.transaction do
      @business.save!
      @business.categories = categories
      create_default_business_hours
      current_user.update!(role: :business_owner) if current_user.customer?
    end

    redirect_to dashboard_root_path, notice: "Bisnis berhasil didaftarkan dan menunggu verifikasi. Anda sudah bisa melengkapi layanan serta profil di dashboard."
  rescue ActiveRecord::RecordInvalid => e
    @business ||= Business.new
    @business.errors.add(:base, e.record.errors.full_messages.to_sentence) unless e.record == @business
    @cities = City.ordered
    @categories = Category.ordered
    render "pages/business_signup", status: :unprocessable_entity
  end

  private

  def business_params
    params.require(:business).permit(:name, :address, :phone, :city_id, category_ids: [])
  end

  def unique_slug(name)
    base = name.to_s.parameterize.presence || "bisnis"
    candidate = base
    suffix = 2
    while Business.exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end
    candidate
  end

  def create_default_business_hours
    (0..6).each do |weekday|
      BusinessHour.create!(
        business: @business,
        weekday: weekday,
        open_minute: 9 * 60,
        close_minute: 17 * 60,
        closed: weekday.zero?
      )
    end
  end
end

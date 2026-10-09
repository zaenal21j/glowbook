require "rails_helper"

RSpec.describe "Admin workflows", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:business) { create(:business, status: :pending) }

  before do
    travel_to Time.zone.local(2026, 10, 12, 8)
    sign_in admin
  end

  it "renders every admin section in both languages" do
    business
    service = create(:service, business: business)
    user = create(:user)
    booking = create(:booking, business: business, user: user, with_item: service)
    paths = [admin_root_path, admin_users_path, admin_user_path(user),
      admin_businesses_path, admin_business_path(business.id), admin_bookings_path,
      admin_booking_path(booking), admin_categories_path, edit_admin_category_path(service.category),
      admin_reviews_path, admin_promotions_path, admin_reports_path, admin_payments_path, admin_settings_path]
    %i[id en].each do |locale|
      post locale_path(locale)
      paths.each do |path|
        get path
        expect(response).to have_http_status(:ok), "#{locale}: #{path}"
        expect(response.body).not_to match(/translation missing|Translation missing/), "#{locale}: #{path}"
        menu = Nokogiri::HTML(response.body).at_css("header details")
        expect(menu.at_css("summary")["aria-label"]).to eq(I18n.t("glowbook.nav.menu", locale: locale))
        expect(menu.css("a").map { |link| link["href"] }).to include(admin_users_path, admin_businesses_path, admin_reports_path)
      end
    end
  end

  it "approves a business through the action shown in the admin list" do
    business
    get admin_businesses_path(status: "pending")
    doc = Nokogiri::HTML(response.body)
    action = activate_admin_business_path(business.id)
    expect(doc.css('form').map { |form| form["action"] }).to include(action)
    expect(doc.css('a').map { |link| link["href"] }).to include(admin_business_path(business.id))
    patch action
    expect(business.reload).to be_active
    get business_detail_path(business.slug)
    expect(response).to have_http_status(:ok)
  end

  it "suspends and reactivates without deleting any booking history" do
    business.update!(status: :active)
    booking = create(:booking, business: business)
    expect { delete admin_business_path(business.id) }.not_to change(Booking, :count)
    expect(business.reload).to be_suspended
    expect(Booking.exists?(booking.id)).to be(true)
    get business_detail_path(business.slug)
    expect(response).to have_http_status(:not_found)
    patch reactivate_admin_business_path(business.id)
    expect(business.reload).to be_active
  end

  it "shows category errors and retains the invalid form's submitted values" do
    category = create(:category)
    post admin_categories_path, params: { category: { name: "Retained category name", slug: category.slug } }
    expect(response).to have_http_status(:unprocessable_entity)
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('input[name="category[name]"]')["value"]).to eq("Retained category name")
    expect(doc.at_css('input[name="category[slug]"]')["value"]).to eq(category.slug)
    expect(response.body).to include(I18n.t("scheduling.review_errors"))
  end

  it "creates, edits, promotes, and deletes an unused category" do
    post admin_categories_path, params: { category: { name: "New Category", slug: "new-category" } }
    category = Category.find_by!(slug: "new-category")
    patch admin_category_path(category), params: { category: { name: "Updated Category" } }
    expect(category.reload.name).to eq("Updated Category")
    patch toggle_popular_admin_category_path(category)
    expect(category.reload.is_popular).to be(true)
    delete admin_category_path(category)
    expect(Category.exists?(category.id)).to be(false)
  end

  it "protects a category used by a service" do
    service = create(:service)
    delete admin_category_path(service.category)
    expect(Category.exists?(service.category_id)).to be(true)
    expect(service.reload.category).to be_present
  end

  it "protects the signed-in admin and users with booking history" do
    booking = create(:booking)
    delete admin_user_path(admin)
    expect(User.exists?(admin.id)).to be(true)
    delete admin_user_path(booking.user)
    expect(User.exists?(booking.user_id)).to be(true)
    expect(Booking.exists?(booking.id)).to be(true)
  end

  it "rejects invalid planned commission settings and persists valid ones" do
    setting = PlatformSetting.current
    original = setting.commission_percentage
    patch admin_settings_path, params: { platform_setting: { commission_percentage: 101 } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(setting.reload.commission_percentage).to eq(original)
    patch admin_settings_path, params: { platform_setting: { commission_percentage: "7.50", business_registration_open: "0" } }
    expect(response).to redirect_to(admin_settings_path)
    expect(setting.reload.commission_percentage).to eq(BigDecimal("7.5"))
    expect(setting.business_registration_open).to be(false)
  end

  it "lets the admin close business registration" do
    PlatformSetting.current.update!(business_registration_open: false)
    sign_in create(:user)
    expect {
      post buat_registrasi_bisnis_path, params: { business: { name: "Blocked registration" } }
    }.not_to change(Business, :count)
    expect(response).to redirect_to(registrasi_bisnis_path)
  end

  it "exports a completed booking report as CSV" do
    booking = create(:booking, :past, business: business)
    get admin_reports_path(format: :csv, month: "2026-10")
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(response.body).to include(booking.reference, business.name)
    expect(response.body.lines.first).to include('"Kode Booking"', '"Pelanggan"')
    get admin_payments_path(format: :csv, month: "2026-10")
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(response.body.lines.first).to include('"Tanggal Booking"', '"Nominal IDR"')
    post locale_path(:en)
    get admin_reports_path(format: :csv, month: "2026-10")
    expect(response.body.lines.first).to include('"Booking reference"', '"Customer"')
    get admin_payments_path(format: :csv, month: "2026-10")
    expect(response.body.lines.first).to include('"Booking date"', '"Amount IDR"')
  end

  it "ranks same-named businesses separately using only completed bookings in the selected month" do
    first = create(:business, name: "Glow Studio", city: create(:city, name: "Jakarta"))
    second = create(:business, name: "Glow Studio", city: create(:city, name: "Bandung"))
    create(:booking, :past, business: first, total_amount: 200_000)
    create(:booking, :past, business: first, total_amount: 50_000)
    create(:booking, :past, business: second, total_amount: 500_000)
    create(:booking, :past, business: first, total_amount: 10_000_000, status: :cancelled)
    create(:booking, :past, business: first, total_amount: 9_000_000,
      start_time: Time.zone.local(2026, 9, 20, 10), end_time: Time.zone.local(2026, 9, 20, 11))

    %i[id en].each do |locale|
      post locale_path(locale)
      get admin_reports_path(month: "2026-10")
      expect(response).to have_http_status(:ok)
      rows = Nokogiri::HTML(response.body).css("ol > li")
      expect(rows.map { |row| row.at_css("a")["href"] }).to eq([admin_business_path(second.id), admin_business_path(first.id)])
      expect(rows.map { |row| row.at_css("a").text }).to eq(["Glow Studio", "Glow Studio"])
      expect(rows.map { |row| row.at_css("strong").text }).to eq(["Rp 500.000", "Rp 250.000"])
      expect(rows.first.text).to include("Bandung")
      expect(rows.last.text).to include("Jakarta")
    end
  end

  it "rejects a customer from every admin mutation" do
    sign_in create(:user)
    patch activate_admin_business_path(business.id)
    expect(response).to redirect_to(root_path)
    expect(business.reload).to be_pending
    post admin_categories_path, params: { category: { name: "Unauthorized", slug: "unauthorized" } }
    expect(response).to redirect_to(root_path)
    expect(Category.exists?(slug: "unauthorized")).to be(false)
  end

  it "serves account registration and never accepts an elevated role from signup" do
    sign_out admin
    get signup_path
    expect(response).to have_http_status(:ok)
    expect {
      post user_registration_path, params: { user: { name: "New Customer", email: "new-customer@example.com",
        password: "password123", phone: "", role: "admin" } }
    }.to change(User, :count).by(1)
    expect(User.find_by!(email: "new-customer@example.com")).to be_customer
  end

  it "protects retained customer history from self-service account deletion" do
    booking = create(:booking)
    sign_in booking.user
    expect { delete user_registration_path }.not_to change(User, :count)
    expect(response).to redirect_to(account_settings_path)
    expect(Booking.exists?(booking.id)).to be(true)
    get account_settings_path
    expect(response).to have_http_status(:ok)
  end

  it "renders invalid signup errors in Indonesian" do
    sign_out admin
    post user_registration_path, params: { user: { name: "", email: "invalid", password: "short" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("Tidak dapat menyimpan")
    expect(response.body).not_to match(/translation missing|Translation missing/)
  end
end

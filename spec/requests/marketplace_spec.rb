require "rails_helper"

RSpec.describe "Public marketplace", type: :request do
  before { travel_to Time.zone.local(2026, 10, 12, 8) }

  def result_links
    Nokogiri::HTML(response.body).css('a[href^="/b/"]').map { |link| link["href"] }
      .select { |href| href.match?(%r{\A/b/[^/]+\z}) }.uniq
  end

  it "renders the homepage and search on an empty production database" do
    expect(City.count).to eq(0)
    [root_path, search_path].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to match(/translation missing/i)
    end
  end

  it "lists active businesses and hides pending and suspended businesses" do
    active = create(:business)
    pending = create(:business, status: :pending)
    suspended = create(:business, status: :suspended)
    [root_path, search_path].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(result_links).to include(business_detail_path(active.slug))
      expect(result_links).not_to include(business_detail_path(pending.slug), business_detail_path(suspended.slug))
    end
  end

  it "filters businesses open today without listing closed businesses" do
    open_business = create(:business)
    closed_business = create(:business)
    closed_business.business_hours.find_by!(weekday: 1).update!(closed: true)
    get search_path, params: { open_today: "1" }
    expect(response).to have_http_status(:ok)
    expect(result_links).to include(business_detail_path(open_business.slug))
    expect(result_links).not_to include(business_detail_path(closed_business.slug))
  end

  it "filters and sorts using active service prices" do
    expensive = create(:business)
    affordable = create(:business)
    create(:service, business: expensive, price: 200_000)
    create(:service, business: expensive, price: 1_000, active: false)
    create(:service, business: affordable, price: 50_000)
    get search_path, params: { min_price: 25_000, max_price: 100_000, sort: "price" }
    expect(response).to have_http_status(:ok)
    expect(result_links).to eq([business_detail_path(affordable.slug)])
    get search_path, params: { sort: "price" }
    expect(result_links).to eq([affordable, expensive].map { |item| business_detail_path(item.slug) })
  end

  it "combines city, category, rating, and current promotion filters without duplicate businesses" do
    category = create(:category)
    business = create(:business, avg_rating: 4.8)
    business.categories << category
    create_list(:promotion, 2, business: business)
    create(:business, city: business.city, avg_rating: 3)
    get search_path, params: { city: business.city.slug, categories: [category.slug], min_rating: 4, promo: "1" }
    expect(response).to have_http_status(:ok)
    expect(result_links).to eq([business_detail_path(business.slug)])
    expect(response.body).to include(I18n.t("search.found", count: 1))
    get city_path(business.city.slug)
    expect(response).to have_http_status(:ok)
    get category_path(category.slug)
    expect(response).to redirect_to(search_path(categories: [category.slug]))
  end

  it "orders by nearby coordinates, expires the origin, and rejects invalid coordinates" do
    near = create(:business, latitude: -6.2, longitude: 106.8)
    far = create(:business, latitude: -7.2, longitude: 110.8)
    post nearby_search_path, params: { latitude: -6.2, longitude: 106.8 }
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(result_links).to eq([near, far].map { |item| business_detail_path(item.slug) })
    travel 31.minutes
    get search_path, params: { sort: "nearby" }
    expect(response.body).to include(I18n.t("search.nearby_permission"))
    post nearby_search_path, params: { latitude: "NaN", longitude: 400 }
    expect(response).to redirect_to(search_path)
  end

  it "clamps pagination and renders an English empty search" do
    create_list(:business, 13)
    get search_path, params: { page: 99 }
    expect(response).to have_http_status(:ok)
    expect(result_links.size).to eq(1)
    post locale_path(:en)
    get search_path, params: { q: "No matching business" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("0 businesses found")
    expect(response.body).not_to match(/translation missing/i)
  end
end

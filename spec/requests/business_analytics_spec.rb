require "rails_helper"

RSpec.describe "Business analytics", type: :request do
  let(:owner) { create(:user, :owner) }
  let(:business) { create(:business, owner: owner) }

  before do
    travel_to Time.zone.local(2026, 10, 12, 12)
    sign_in owner
  end

  def metric(key, locale)
    card = Nokogiri::HTML(response.body).css(".card").find do |element|
      element.at_css("p")&.text == I18n.t("dashboard.analytics_page.#{key}", locale: locale)
    end
    card.at_css(".text-2xl").text.strip
  end

  it "limits monthly metrics to this business and counts first-time customers once" do
    returning = create(:user)
    newcomer = create(:user)
    create(:booking, :past, business: business, user: returning, total_amount: 9_000_000,
      start_time: Time.zone.local(2026, 9, 30, 23), end_time: Time.zone.local(2026, 9, 30, 23, 30))
    create(:booking, :past, business: business, user: returning, total_amount: 200_000,
      start_time: Time.zone.local(2026, 10, 1), end_time: Time.zone.local(2026, 10, 1, 1))
    create(:booking, :past, business: business, user: newcomer, total_amount: 100_000)
    create(:booking, :past, business: business, user: newcomer, total_amount: 50_000)
    create(:booking, business: business, user: newcomer,
      start_time: Time.zone.local(2026, 10, 25, 10), end_time: Time.zone.local(2026, 10, 25, 11))
    create(:booking, business: business,
      start_time: Time.zone.local(2026, 11, 1), end_time: Time.zone.local(2026, 11, 1, 1))
    create(:booking, :past, business: business, total_amount: 10_000_000,
      start_time: Time.zone.local(2026, 11, 5, 10), end_time: Time.zone.local(2026, 11, 5, 11))
    create(:booking, :past, total_amount: 20_000_000)

    %i[id en].each do |locale|
      post locale_path(locale)
      get dashboard_analytics_path
      expect(response).to have_http_status(:ok)
      expect(metric(:bookings_month, locale)).to eq("4")
      expect(metric(:completed_value, locale)).to eq("Rp 350.000")
      expect(metric(:new_customers, locale)).to eq("1")
      expect(response.body).to include(I18n.t("dashboard.analytics_page.new_customers_note", locale: locale))
    end
  end

  it "groups the completed value chart by the Jakarta day" do
    create(:booking, :past, business: business, total_amount: 200_000,
      start_time: Time.zone.local(2026, 10, 9, 23, 30), end_time: Time.zone.local(2026, 10, 10))
    create(:booking, :past, business: business, total_amount: 100_000,
      start_time: Time.zone.local(2026, 10, 10, 0, 30), end_time: Time.zone.local(2026, 10, 10, 1))
    get dashboard_analytics_path
    expect(response).to have_http_status(:ok)
    bars = Nokogiri::HTML(response.body).css(".h-44 [title]").map { |element| element["title"] }
    expect(bars.length).to eq(30)
    expect(bars).to include("09 Okt: Rp 200.000", "10 Okt: Rp 100.000", "11 Okt: Rp 0")
  end

  it "ranks services by appointment month and excludes cancelled and other-business bookings" do
    service = create(:service, business: business, name: "Scheduled facial")
    scheduled = create(:booking, :past, business: business, with_item: service)
    scheduled.booking_items.first.update!(created_at: Time.zone.local(2026, 9, 25))
    create(:booking, business: business, with_item: service,
      start_time: Time.zone.local(2026, 11, 1, 10), end_time: Time.zone.local(2026, 11, 1, 11))
    cancelled = create(:service, business: business, name: "Cancelled service")
    create(:booking, :past, business: business, with_item: cancelled, status: :cancelled)
    previous = create(:service, business: business, name: "Previous month service")
    create(:booking, :past, business: business, with_item: previous,
      start_time: Time.zone.local(2026, 9, 30, 10), end_time: Time.zone.local(2026, 9, 30, 11))
    foreign = create(:service, name: "Other business service")
    create(:booking, :past, business: foreign.business, with_item: foreign)

    get dashboard_analytics_path
    expect(response).to have_http_status(:ok)
    popular = Nokogiri::HTML(response.body).css(".card").last.text
    expect(popular).to include("Scheduled facial", "1x")
    expect(popular).not_to include("2x", "Cancelled service", "Previous month service", "Other business service")
  end
end

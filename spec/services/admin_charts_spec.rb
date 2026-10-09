require "rails_helper"

RSpec.describe AdminCharts do
  before { travel_to Time.zone.local(2026, 10, 12, 12) }

  it "groups counts and completed value by Jakarta date rather than UTC date" do
    business = create(:business)
    create(:booking, :past, business: business, total_amount: 200_000,
      start_time: Time.zone.local(2026, 10, 9, 23, 30), end_time: Time.zone.local(2026, 10, 10))
    create(:booking, :past, business: business, total_amount: 100_000,
      start_time: Time.zone.local(2026, 10, 10, 0, 30), end_time: Time.zone.local(2026, 10, 10, 1))
    create(:booking, :past, business: business, status: :confirmed, total_amount: 70_000,
      start_time: Time.zone.local(2026, 10, 10, 18, 30), end_time: Time.zone.local(2026, 10, 10, 19))

    chart = described_class.new(scope_date: Date.new(2026, 10, 9)..Date.new(2026, 10, 11))
    expect(chart.daily_counts.values).to eq([1, 2, 0])
    expect(chart.daily_revenue.values).to eq([200_000, 100_000, 0])
    expect(chart.max_count).to eq(2)
    expect(chart.max_revenue).to eq(200_000)
  end

  it "excludes appointments outside the requested local date range" do
    business = create(:business)
    create(:booking, :past, business: business,
      start_time: Time.zone.local(2026, 10, 8, 23, 59), end_time: Time.zone.local(2026, 10, 9))
    create(:booking, :past, business: business,
      start_time: Time.zone.local(2026, 10, 12), end_time: Time.zone.local(2026, 10, 12, 1))
    chart = described_class.new(scope_date: Date.new(2026, 10, 9)..Date.new(2026, 10, 11))
    expect(chart.daily_counts.values).to eq([0, 0, 0])
    expect(chart.daily_revenue.values).to eq([0, 0, 0])
  end
end

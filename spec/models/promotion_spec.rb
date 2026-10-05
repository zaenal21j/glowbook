require 'rails_helper'

RSpec.describe Promotion do
  it "rejects ends_at before starts_at" do
    promo = build(:promotion, starts_at: 1.day.from_now, ends_at: 1.day.ago)
    expect(promo).not_to be_valid
  end

  it "active_now includes running promos and excludes expired" do
    running = create(:promotion)
    expired = create(:promotion, starts_at: 2.months.ago, ends_at: 1.month.ago)

    expect(Promotion.active_now).to include(running)
    expect(Promotion.active_now).not_to include(expired)
  end

  it "restricts discount percent to 1..90" do
    expect(build(:promotion, discount_percent: 95)).not_to be_valid
  end
end

require 'rails_helper'

RSpec.describe Business do
  it "is valid with factory defaults" do
    expect(build(:business)).to be_valid
  end

  it "requires unique slug" do
    existing = create(:business)
    dup = build(:business, name: "Duplikat", slug: existing.slug)
    expect(dup).not_to be_valid
  end

  describe "#open_now?" do
    it "is false when closed today" do
      business = create(:business, closed_sunday: true)
      travel_to Time.zone.local(2026, 6, 7, 10) do # Minggu
        expect(business.open_now?).to be(false)
      end
    end
  end

  describe "#price_from" do
    it "returns minimum service price" do
      business = create(:business)
      create(:service, business: business, price: 80_000)
      create(:service, business: business, price: 120_000)
      expect(business.price_from).to eq(80_000)
    end

    it "is 0 without services" do
      expect(create(:business).price_from).to eq(0)
    end
  end
end

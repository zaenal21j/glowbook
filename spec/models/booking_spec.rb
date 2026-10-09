require 'rails_helper'

RSpec.describe Booking do
  describe "validations" do
    it "is valid with factory defaults" do
      booking = build(:booking, with_item: nil)
      expect(booking).to be_valid
    end

    it "requires end after start" do
      booking = build(:booking, start_time: 1.day.from_now.noon, end_time: 1.day.from_now.noon - 1.hour)
      expect(booking).not_to be_valid
    end

    it "rejects bookings in the past on create" do
      booking = build(:booking, start_time: 1.day.ago, end_time: 1.day.ago + 1.hour)
      expect(booking).not_to be_valid
    end

    it "generates a GB reference on create" do
      booking = create(:booking)
      expect(booking.reference).to match(/\AGB-\d{8}-\d{6}\z/)
    end

    it "validates status inclusion" do
      booking = build(:booking)
      expect { booking.status = "bogus" }.to raise_error(ArgumentError)
    end

    it "defaults to pending" do
      expect(Booking.new.status).to eq("pending")
    end
  end

  describe "scopes" do
    it "uses the same exact local month boundaries for Date and Time inputs" do
      travel_to Time.zone.local(2026, 10, 12, 12)
      business = create(:business)
      previous = create(:booking, :past, business: business,
        start_time: Time.zone.local(2026, 9, 30, 23, 59), end_time: Time.zone.local(2026, 10, 1))
      first = create(:booking, :past, business: business,
        start_time: Time.zone.local(2026, 10, 1), end_time: Time.zone.local(2026, 10, 1, 1))
      last = create(:booking, business: business,
        start_time: Time.zone.local(2026, 10, 31, 23, 59), end_time: Time.zone.local(2026, 11, 1, 0, 30))
      following = create(:booking, business: business,
        start_time: Time.zone.local(2026, 11, 1), end_time: Time.zone.local(2026, 11, 1, 1))
      [Date.new(2026, 10, 12), Time.zone.local(2026, 10, 12, 12)].each do |month|
        expect(business.bookings.in_month(month)).to contain_exactly(first, last)
      end
      expect(business.bookings.in_month(Time.current.beginning_of_month)).not_to include(previous, following)
    end

    it "upcoming excludes past and cancelled" do
      business = create(:business)
      upcoming = create(:booking, business: business, start_time: 2.days.from_now.change(hour: 14), end_time: 2.days.from_now.change(hour: 15))
      past = build(:booking, business: business, start_time: 2.days.ago, end_time: 2.days.ago + 1.hour, status: :completed)
      past.reference = "GB-PAST-TEST-01" # dilewati before_validation (validate: false)
      past.save!(validate: false)
      create(:booking, business: business, start_time: 3.days.from_now, end_time: 3.days.from_now + 1.hour, status: :cancelled)

      expect(business.bookings.upcoming).to contain_exactly(upcoming)
    end
  end
end

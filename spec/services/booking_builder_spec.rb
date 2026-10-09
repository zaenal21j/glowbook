require 'rails_helper'

RSpec.describe BookingBuilder do
  let(:user)     { create(:user) }
  let(:business) { create(:business, open_hour: 9, close_hour: 17) }
  let(:service)  { create(:service, business: business, duration_minutes: 60, price: 150_000) }
  let(:member)   { create(:staff, business: business, start_hour: 9, end_hour: 17) }

  before do
    travel_to Time.zone.local(2026, 10, 12, 8)
    create(:staff_service, staff: member, service: service)
  end

  def tomorrow_at(hour, min = 0)
    Time.zone.now.to_date.next_day(1).in_time_zone.change(hour: hour, min: min)
  end

  def build_booking(start_time, staff_id: nil)
    described_class.new(
      user: user,
      business: business,
      service_ids: [service.id],
      staff_id: staff_id,
      start_time: start_time
    )
  end

  context "happy path" do
    it "creates a confirmed booking with items" do
      result = build_booking(tomorrow_at(10)).call

      expect(result).to be_ok
      expect(result.booking.status).to eq("confirmed")
      expect(result.booking.total_amount).to eq(150_000)
      expect(result.booking.booking_items.count).to eq(1)
      expect(result.booking.booking_items.first.staff).to eq(member)
      expect(result.booking.booking_items.first.during).to be_a(Range)
    end

    it "auto-picks a free staff when none is chosen" do
      other = create(:staff, business: business, name: "Staff Lain", start_hour: 9, end_hour: 17)
      create(:staff_service, staff: other, service: service)

      result = build_booking(tomorrow_at(10)).call
      expect(result).to be_ok
      expect(result.booking.booking_items.first.staff).to eq(member)
    end

    it "chains multiple services back-to-back" do
      second = create(:service, business: business, name: "Layanan Dua",
                                duration_minutes: 30, price: 50_000)
      create(:staff_service, staff: member, service: second)

      result = described_class.new(
        user: user, business: business,
        service_ids: [service.id, second.id],
        start_time: tomorrow_at(9)
      ).call

      expect(result).to be_ok
      items = result.booking.booking_items.order(:during)
      expect(items.first.during.last).to eq(items.second.during.first)
    end
  end

  context "validation failures" do
    it "rejects a slot outside staff working hours" do
      result = build_booking(tomorrow_at(20)).call
      expect(result).not_to be_ok
      expect(result.error).to be_present
    end

    it "rejects a slot overlapping an existing booking" do
      create(:booking, business: business,
                       start_time: tomorrow_at(10), end_time: tomorrow_at(11),
                       with_item: service, with_item_staff: member)

      result = build_booking(tomorrow_at(10, 30)).call
      expect(result).not_to be_ok
    end

    it "rejects an explicitly chosen staff that does not serve the service" do
      stranger = create(:staff, business: business, name: "Stranger")
      result = build_booking(tomorrow_at(10), staff_id: stranger.id).call
      expect(result).not_to be_ok
    end

    it "rejects unknown services" do
      result = described_class.new(
        user: user, business: business,
        service_ids: [service.id, 999_999],
        start_time: tomorrow_at(10)
      ).call
      expect(result).not_to be_ok
    end
  end

  context "database-level double booking (exclusion constraint)" do
    it "raises RecordNotUnique → friendly error when two bookings race for the same staff" do
      create(:booking, business: business,
                       start_time: tomorrow_at(10), end_time: tomorrow_at(11),
                       with_item: service, with_item_staff: member)

      # Seed availability check bypassed: insert langsung menembus constraint.
      booking = build(:booking, business: business,
                                start_time: tomorrow_at(10, 30), end_time: tomorrow_at(11, 30))
      booking.reference = "GB-RACE-TEST-01" # before_validation dilewati (validate: false)
      item = BookingItem.new(booking: booking, service: service, staff: member,
                             price: service.price, duration_minutes: 60,
                             during: tomorrow_at(10, 30)...tomorrow_at(11, 30))
      booking.save(validate: false)
      expect { item.save! }.to raise_error(ActiveRecord::ExclusionViolation)
    end
  end
end

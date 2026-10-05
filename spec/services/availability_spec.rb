require 'rails_helper'

RSpec.describe Availability do
  # Karena granularitas slot 30 menit, semua contoh memakai jam bulat.
  let(:business) { create(:business, open_hour: 9, close_hour: 17) }
  let(:service)  { create(:service, business: business, duration_minutes: 60) }
  let(:member)   { create(:staff, business: business, start_hour: 9, end_hour: 17) }

  before { create(:staff_service, staff: member, service: service) }

  def at(day_offset, hour, min = 0)
    Time.zone.now.to_date.next_day(day_offset)
         .in_time_zone.change(hour: hour, min: min)
  end

  def slot_times(day_offset = 1)
    described_class.new(business: business, service: service, date: Time.zone.now.to_date.next_day(day_offset))
                   .slots.map { |s| s[:time].hour }
  end

  it "returns slots inside business & staff hours" do
    expect(slot_times).to all(be_between(9, 16))
  end

  it "first slot is 09:00 and last start 16:00 for 60m service" do
    slots = described_class.new(business: business, service: service, date: Time.zone.now.to_date.next_day(1)).slots
    expect(slots.first[:time].hour).to eq(9)
    expect(slots.last[:time].hour).to eq(16)
  end

  it "excludes staff lunch break 12:00-13:00" do
    wday = Time.zone.now.to_date.next_day(2).wday
    create(:staff_break, staff: member, weekday: wday, start_minute: 12 * 60, end_minute: 13 * 60)
    expect(slot_times(2)).not_to include(12)
  end

  it "excludes blocked times for the staff" do
    day = Time.zone.now.to_date.next_day(3)
    BlockedTime.create!(business: business, staff: member, reason: "Training",
                        start_time: at(3, 10), end_time: at(3, 12))
    slots = described_class.new(business: business, service: service, date: day).slots.map { |s| s[:time].hour }
    expect(slots).not_to include(10, 11)
  end

  it "excludes slots overlapping an existing booking" do
    create(:booking, business: business,
                     start_time: at(4, 10), end_time: at(4, 11),
                     with_item: service, with_item_staff: member)
    slots = described_class.new(business: business, service: service, date: Time.zone.now.to_date.next_day(4)).slots.map { |s| s[:time].hour }
    expect(slots).not_to include(10)
    expect(slots).to include(9)   # berakhir tepat saat booking mulai
    expect(slots).to include(11)  # mulai tepat saat booking selesai
  end

  it "returns no slots on closed days" do
    # Cari Minggu berikutnya (weekday 0) — bisnis tutup pada Minggu
    sunday = Date.current.next_occurring(:sunday)
    slots = described_class.new(business: business, service: service, date: sunday).slots
    expect(slots).to be_empty
  end

  it "is empty for dates in the past" do
    slots = described_class.new(business: business, service: service, date: Date.current - 1).slots
    expect(slots).to be_empty
  end

  describe "#available_at?" do
    it "is true for a valid slot" do
      engine = described_class.new(business: business, service: service, date: Time.zone.now.to_date.next_day(1))
      expect(engine.available_at?(at(1, 10))).to be(true)
    end

    it "is false outside hours" do
      engine = described_class.new(business: business, service: service, date: Time.zone.now.to_date.next_day(1))
      expect(engine.available_at?(at(1, 20))).to be(false)
    end
  end
end

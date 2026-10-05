require 'rails_helper'

RSpec.describe StaffSchedule do
  it "rejects end before start" do
    member = create(:staff)
    schedule = StaffSchedule.new(staff: member, weekday: 1, start_minute: 10 * 60, end_minute: 9 * 60)
    expect(schedule).not_to be_valid
  end

  it "rejects duplicate weekday start times per staff" do
    member = create(:staff, weekdays: [])
    StaffSchedule.create!(staff: member, weekday: 1, start_minute: 9 * 60, end_minute: 17 * 60)
    dup = StaffSchedule.new(staff: member, weekday: 1, start_minute: 9 * 60, end_minute: 17 * 60)
    expect(dup).not_to be_valid
  end
end

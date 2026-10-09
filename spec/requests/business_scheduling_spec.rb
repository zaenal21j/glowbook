require "rails_helper"

RSpec.describe "Business scheduling", type: :request do
  let(:owner) { create(:user, :owner) }
  let(:business) { create(:business, owner: owner) }
  let(:service) { create(:service, business: business) }
  let(:member) { create(:staff, business: business, weekdays: []) }
  let(:date) { Date.new(2026, 10, 13) }

  before do
    travel_to Time.zone.local(2026, 10, 12, 8)
    business
    sign_in owner
  end

  def slots(staff = member)
    Availability.new(business: business.reload, service: service, staff: staff, date: date)
                .slots.map { |slot| slot[:time].strftime("%H:%M") }
  end

  def shift_attributes(start_minute: 540, end_minute: 1020)
    { weekday: date.wday, start_minute: start_minute, end_minute: end_minute }
  end

  def associate_service(staff = member)
    create(:staff_service, staff: staff, service: service)
  end

  it "renders the staff form with its persisted bio field" do
    get new_dashboard_manage_staff_path
    expect(response).to have_http_status(:ok)
    mobile_menu = Nokogiri::HTML(response.body).at_css("header details")
    expect(mobile_menu.css("a").map { |link| link["href"] }).to include(dashboard_staffs_path, dashboard_blocked_times_path, dashboard_profile_path)
    post dashboard_manage_staffs_path, params: { staff: { name: "Ayu", bio: "Senior stylist", active: true, service_ids: [service.id] } }
    created = business.staff.find_by!(name: "Ayu")
    expect(created.bio).to eq("Senior stylist")
    expect(response).to redirect_to(dashboard_staff_availability_path(created))
  end

  it "saves opening hours and immediately changes available slots" do
    associate_service
    member.staff_schedules.create!(shift_attributes)
    hour = business.business_hours.find_by!(weekday: date.wday)
    get dashboard_profile_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("business[business_hours_attributes]")

    patch dashboard_profile_path, params: { business: { business_hours_attributes: { "0" => { id: hour.id, open_minute: 660, close_minute: 900, closed: "0" } } } }
    expect(response).to redirect_to(dashboard_profile_path)
    expect(slots.first).to eq("11:00")
    expect(slots.last).to eq("14:00")
  end

  it "rolls back the whole profile when opening hours are invalid" do
    hour = business.business_hours.find_by!(weekday: date.wday)
    name = business.name
    patch dashboard_profile_path, params: { business: { name: "Invalid change", business_hours_attributes: { "0" => { id: hour.id, open_minute: 1000, close_minute: 600, closed: "0" } } } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(business.reload.name).to eq(name)
    expect(hour.reload.open_minute).to eq(540)
  end

  it "does not allow another business's nested opening hour to be edited" do
    foreign = create(:business).business_hours.find_by!(weekday: 1)
    patch dashboard_profile_path, params: { business: { business_hours_attributes: { "0" => { id: foreign.id, closed: "1" } } } }
    expect(response).to have_http_status(:not_found)
    expect(foreign.reload.closed?).to be(false)
  end

  it "supports two separate shifts and rejects overlapping shifts" do
    associate_service
    post dashboard_staff_shifts_path(member), params: { staff_schedule: shift_attributes(end_minute: 720) }
    expect(response).to redirect_to(dashboard_staff_availability_path(member))
    post dashboard_staff_shifts_path(member), params: { staff_schedule: shift_attributes(start_minute: 840) }
    expect(slots).to include("09:00", "11:00", "14:00", "16:00")
    expect(slots).not_to include("12:00", "13:00")

    expect {
      post dashboard_staff_shifts_path(member), params: { staff_schedule: shift_attributes(start_minute: 660, end_minute: 900) }
    }.not_to change(StaffSchedule, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "edits and removes an existing shift" do
    associate_service
    shift = member.staff_schedules.create!(shift_attributes)
    patch dashboard_staff_shift_path(member, shift), params: { staff_schedule: { start_minute: 660 } }
    expect(slots.first).to eq("11:00")
    delete dashboard_staff_shift_path(member, shift)
    expect(slots).to be_empty
  end

  it "copies business hours once without overwriting staff customization" do
    post dashboard_copy_staff_hours_path(member)
    expect(member.staff_schedules.count).to eq(6)
    member.staff_schedules.find_by!(weekday: date.wday).update!(start_minute: 660)
    post dashboard_copy_staff_hours_path(member)
    expect(member.staff_schedules.count).to eq(6)
    expect(member.staff_schedules.find_by!(weekday: date.wday).start_minute).to eq(660)
  end

  it "applies added, edited, and deleted breaks to availability" do
    associate_service
    member.staff_schedules.create!(shift_attributes)
    post dashboard_staff_breaks_path(member), params: { staff_break: shift_attributes(start_minute: 720, end_minute: 780) }
    expect(slots).not_to include("11:30", "12:00", "12:30")
    staff_break = member.staff_breaks.sole
    patch dashboard_staff_break_path(member, staff_break), params: { staff_break: { start_minute: 780, end_minute: 840 } }
    expect(slots).to include("12:00")
    expect(slots).not_to include("13:00")
    delete dashboard_staff_break_path(member, staff_break)
    expect(slots).to include("13:00")
  end

  it "blocks only the selected staff and then the entire business" do
    associate_service
    member.staff_schedules.create!(shift_attributes)
    other = create(:staff, business: business)
    associate_service(other)
    attributes = { reason: "Training", start_time: "2026-10-13T10:00", end_time: "2026-10-13T12:00", staff_id: member.id }
    post dashboard_blocked_times_path, params: { blocked_time: attributes }
    expect(response).to redirect_to(dashboard_blocked_times_path)
    expect(slots).not_to include("10:00", "11:00")
    expect(slots(other)).to include("10:00")
    block = business.blocked_times.sole
    patch dashboard_blocked_time_path(block), params: { blocked_time: { staff_id: "" } }
    expect(slots(other)).not_to include("10:00")
    delete dashboard_blocked_time_path(block)
    expect(slots).to include("10:00")
    expect(slots(other)).to include("10:00")
  end

  it "rejects a block for staff belonging to another business" do
    foreign = create(:staff)
    expect {
      post dashboard_blocked_times_path, params: { blocked_time: { reason: "Invalid", start_time: "2026-10-13T10:00", end_time: "2026-10-13T12:00", staff_id: foreign.id } }
    }.not_to change(BlockedTime, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "renders invalid empty time input with errors instead of crashing" do
    post dashboard_staff_shifts_path(member), params: { staff_schedule: { weekday: 1, start_minute: "", end_minute: "" } }
    expect(response).to have_http_status(:unprocessable_entity)
    post dashboard_staff_breaks_path(member), params: { staff_break: { weekday: 1, start_minute: "", end_minute: "" } }
    expect(response).to have_http_status(:unprocessable_entity)
    post dashboard_blocked_times_path, params: { blocked_time: { reason: "Empty times", start_time: "", end_time: "" } }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "does not expose inactive staff as bookable even when explicitly selected" do
    associate_service
    member.staff_schedules.create!(shift_attributes)
    member.update!(active: false)
    expect(slots).to be_empty
    expect(Availability.new(business: business, service: service, date: date).slots).to be_empty
  end

  it "isolates schedule and block management between businesses" do
    foreign = create(:staff)
    get dashboard_staff_availability_path(foreign)
    expect(response).to have_http_status(:not_found)
    shift = foreign.staff_schedules.first
    sign_in owner
    patch dashboard_staff_shift_path(member, shift), params: { staff_schedule: { start_minute: 600 } }
    expect(response).to have_http_status(:not_found)
    block = BlockedTime.create!(business: foreign.business, reason: "Private", start_time: 1.day.from_now, end_time: 2.days.from_now)
    sign_in owner
    delete dashboard_blocked_time_path(block)
    expect(response).to have_http_status(:not_found)
    expect(BlockedTime.exists?(block.id)).to be(true)
  end

  it "rejects another business's service and permits clearing all assigned services" do
    associate_service
    foreign = create(:service)
    patch dashboard_manage_staff_path(member), params: { staff: { service_ids: [foreign.id] } }
    expect(response).to have_http_status(:not_found)
    expect(member.services.reload).to contain_exactly(service)
    sign_in owner
    patch dashboard_manage_staff_path(member), params: { staff: { service_ids: [""] } }
    expect(response).to redirect_to(dashboard_staffs_path)
    expect(member.services.reload).to be_empty
  end

  it "preserves booking history when staff or services are deleted" do
    associate_service
    booking = create(:booking, business: business, with_item: service, with_item_staff: member)
    delete dashboard_manage_staff_path(member)
    expect(Staff.exists?(member.id)).to be(true)
    delete dashboard_manage_service_path(service)
    expect(Service.exists?(service.id)).to be(true)
    expect(booking.booking_items.reload.sole.staff_id).to eq(member.id)
  end

  it "blocks customers from changing business schedules" do
    sign_out owner
    sign_in create(:user)
    expect {
      post dashboard_staff_shifts_path(member), params: { staff_schedule: shift_attributes }
    }.not_to change(StaffSchedule, :count)
    expect(response).to redirect_to(root_path)
  end

  it "renders both new management screens in English" do
    post locale_path(:en)
    get dashboard_staff_availability_path(member)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Weekly shifts", "Weekly breaks")
    get dashboard_blocked_times_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Blocked times", "Add blocked time")
  end

  it "revokes dashboard access when a staff account is inactive" do
    user = create(:user)
    member.update!(user: user, active: false)
    sign_out owner
    sign_in user
    get dashboard_staff_availability_path(member)
    expect(response).to redirect_to(root_path)
  end
end

require "rails_helper"

RSpec.describe "Booking schedules", type: :request do
  let(:customer) { create(:user) }
  let(:business) { create(:business) }
  let(:first_service) { create(:service, business: business, duration_minutes: 15, price: 25_000) }
  let(:second_service) { create(:service, business: business, duration_minutes: 45, price: 75_000) }
  let(:member) { create(:staff, business: business) }
  let(:date) { Date.new(2026, 10, 13) }
  let(:start_time) { date.in_time_zone.change(hour: 9) }

  before do
    travel_to Time.zone.local(2026, 10, 12, 8)
    create(:staff_service, staff: member, service: first_service)
    create(:staff_service, staff: member, service: second_service)
    sign_in customer
  end

  def appointment
    BookingBuilder.new(user: customer, business: business,
      service_ids: [first_service.id, second_service.id], staff_id: member.id,
      start_time: start_time).call.booking.tap { |booking| expect(booking).to be_present }
  end

  def choose_services
    get business_book_path(business.slug)
    patch business_book_update_path(business.slug, "layanan"),
      params: { service_ids: [first_service.id, second_service.id] }
    patch business_book_update_path(business.slug, "staff"), params: { staff_id: member.id }
    patch business_book_update_path(business.slug, "tanggal"), params: { date: date.iso8601 }
  end

  def shown_times
    Nokogiri::HTML(response.body).css('input[name="time"]').map { |input| Time.zone.iso8601(input["value"]) }
  end

  it "books 15 and 45 minute services through every real customer step" do
    choose_services
    get business_book_step_path(business.slug, "waktu")
    expect(response).to have_http_status(:ok)
    expect(shown_times).to include(start_time)
    expect(shown_times.last).to eq(date.in_time_zone.change(hour: 16))
    patch business_book_update_path(business.slug, "waktu"), params: { time: start_time.iso8601 }
    get business_book_confirmation_path(business.slug)
    expect(response).to have_http_status(:ok)
    expect {
      post business_book_complete_path(business.slug), params: { payment_method: "pay_at_venue" }
    }.to change(Booking, :count).by(1)
    booking = customer.bookings.last
    expect(response).to redirect_to(booking_path(booking.reference))
    items = booking.booking_items.order(:id)
    expect(items.first.during).to eq(start_time...(start_time + 15.minutes))
    expect(items.last.during).to eq((start_time + 15.minutes)...(start_time + 1.hour))
    expect(booking.total_amount).to eq(100_000)
  end

  it "does not display a sequence whose later service overlaps a break" do
    member.staff_breaks.create!(weekday: date.wday, start_minute: 570, end_minute: 600)
    choose_services
    get business_book_step_path(business.slug, "waktu")
    expect(shown_times).not_to include(start_time)
    expect(shown_times).to include(start_time + 1.hour)
  end

  it "rejects a submitted start between the displayed slot boundaries" do
    choose_services
    patch business_book_update_path(business.slug, "waktu"), params: { time: (start_time + 15.minutes).iso8601 }
    expect(response).to redirect_to(business_book_step_path(business.slug, "waktu"))
    expect { post business_book_complete_path(business.slug) }.not_to change(Booking, :count)
  end

  it "rejects a time on another date" do
    choose_services
    patch business_book_update_path(business.slug, "waktu"), params: { time: (start_time + 1.day).iso8601 }
    expect(response).to redirect_to(business_book_step_path(business.slug, "waktu"))
  end

  it "renders the selected next calendar month" do
    choose_services
    get business_book_step_path(business.slug, "tanggal"), params: { date: "2026-11-01" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("November 2026", 'value="2026-11-01"')
  end

  it "isolates a booking session from another business" do
    choose_services
    other = create(:business)
    get business_book_step_path(other.slug, "waktu")
    expect(response).to redirect_to(business_book_path(other.slug))
  end

  it "does not silently replace an inactive explicitly selected staff member" do
    choose_services
    member.update!(active: false)
    get business_book_step_path(business.slug, "waktu")
    expect(response).to redirect_to(business_book_step_path(business.slug, "staff"))
  end

  it "uses references for the customer's cancel and reschedule links" do
    booking = appointment
    get booking_path(booking.reference)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(cancel_booking_path(booking.reference), reschedule_booking_path(booking.reference))
    patch cancel_booking_path(booking.reference)
    expect(booking.reload).to be_cancelled
    expect(booking.booking_items.active).to be_empty
  end

  it "renders rescheduling and ignores only this appointment's existing ranges" do
    booking = appointment
    get reschedule_booking_path(booking.reference)
    expect(response).to have_http_status(:ok)
    expect(shown_times).to include(start_time, start_time + 30.minutes)
    expect(response.body).to include(update_schedule_booking_path(booking.reference))
  end

  it "preserves sequential ranges, sold durations, staff, and prices when moved" do
    booking = appointment
    first_service.update!(duration_minutes: 30, price: 150_000)
    second_service.update!(duration_minutes: 60, price: 200_000)
    new_start = start_time + 30.minutes
    patch update_schedule_booking_path(booking.reference), params: { date: date.iso8601, time: new_start.iso8601 }
    expect(response).to redirect_to(booking_path(booking.reference))
    booking.reload
    items = booking.booking_items.order(:id)
    expect(booking.start_time).to eq(new_start)
    expect(booking.end_time).to eq(new_start + 1.hour)
    expect(booking.total_amount).to eq(100_000)
    expect(items.map(&:duration_minutes)).to eq([15, 45])
    expect(items.map(&:price)).to eq([25_000, 75_000])
    expect(items.map(&:staff_id).uniq).to eq([member.id])
    expect(items.first.during.last).to eq(items.last.during.first)
    expect(items.last.during.last).to eq(booking.end_time)
  end

  it "refuses a mismatched rescheduling date and time without changing ranges" do
    booking = appointment
    original = booking.booking_items.order(:id).pluck(:during)
    patch update_schedule_booking_path(booking.reference), params: { date: (date + 1).iso8601, time: start_time.iso8601 }
    expect(response).to redirect_to(reschedule_booking_path(booking.reference))
    expect(booking.booking_items.order(:id).pluck(:during)).to eq(original)
  end

  it "refuses another appointment, a closed day, and times outside business hours" do
    booking = appointment
    occupied = start_time + 2.hours
    create(:booking, business: business, start_time: occupied, end_time: occupied + 1.hour,
      with_item: first_service, with_item_staff: member)
    closed = date.next_occurring(:sunday).in_time_zone.change(hour: 9)
    [occupied, closed, start_time.change(hour: 20)].each do |time|
      result = BookingRescheduler.new(booking: booking, start_time: time).call
      expect(result).not_to be_ok
      expect(booking.reload.start_time).to eq(start_time)
      expect(booking.booking_items.active.count).to eq(2)
    end
  end

  it "rolls back the appointment and all ranges when the database detects a race" do
    booking = appointment
    occupied = start_time + 2.hours
    create(:booking, business: business, start_time: occupied, end_time: occupied + 1.hour,
      with_item: first_service, with_item_staff: member)
    allow_any_instance_of(BookingSequenceAvailability).to receive(:available_at?).and_return(true)
    result = BookingRescheduler.new(booking: booking, start_time: occupied).call
    expect(result).not_to be_ok
    expect(booking.reload.start_time).to eq(start_time)
    expect(booking.booking_items.order(:id).first.during.first).to eq(start_time)
    expect(booking.booking_items.active.count).to eq(2)
  end

  it "denies another customer's attempt to view or change the appointment" do
    booking = appointment
    sign_in create(:user)
    get reschedule_booking_path(booking.reference)
    expect(response).to redirect_to(root_path)
    patch update_schedule_booking_path(booking.reference), params: { date: date.iso8601, time: (start_time + 2.hours).iso8601 }
    expect(response).to redirect_to(root_path)
    expect(booking.reload.start_time).to eq(start_time)
  end

  it "keeps the payment restriction when rescheduling" do
    booking = appointment
    create(:payment_attempt, booking: booking, status: "pending")
    get reschedule_booking_path(booking.reference)
    expect(response).to redirect_to(booking_path(booking.reference))
    patch update_schedule_booking_path(booking.reference), params: { date: date.iso8601, time: (start_time + 2.hours).iso8601 }
    expect(booking.reload.start_time).to eq(start_time)
  end

  it "renders rescheduling in English" do
    booking = appointment
    post locale_path(:en)
    get reschedule_booking_path(booking.reference)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Save new appointment", "Find available times")
    expect(response.body).not_to include("Translation missing")
  end
end

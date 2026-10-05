require 'rails_helper'

RSpec.describe "Booking flow", type: :request do
  let(:user)     { create(:user) }
  let(:owner)    { create(:user, :owner) }
  let(:business) { create(:business, owner: owner, open_hour: 9, close_hour: 17) }
  let(:service)  { create(:service, business: business, duration_minutes: 60) }
  let(:member)   { create(:staff, business: business, start_hour: 9, end_hour: 17) }

  before do
    create(:staff_service, staff: member, service: service)
    sign_in user
  end

  it "serves the flow entry page" do
    get "/b/#{business.slug}/book"
    follow_redirect! if response.redirect?
    expect(response).to have_http_status(:ok)
  end

  it "requires login for the booking flow" do
    delete "/keluar"
    get "/b/#{business.slug}/book"
    expect(response).to redirect_to("/masuk")
  end

  it "books a real slot through the service (guest -> confirmed)" do
    start_time = Time.zone.now.to_date.next_day(1).in_time_zone.change(hour: 10)

    result = BookingBuilder.new(
      user: user,
      business: business,
      service_ids: [service.id],
      staff_id: member.id,
      start_time: start_time
    ).call

    expect(result).to be_ok
    expect(result.booking.reference).to start_with("GB-")
    expect(Booking.exists?(result.booking.id)).to be(true)
  end

  private

  def sign_in(user)
    post "/users/masuk", params: { user: { email: user.email, password: "password123" } }
  end
end

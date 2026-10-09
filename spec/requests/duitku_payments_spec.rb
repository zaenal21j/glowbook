require "rails_helper"
require "openssl"

RSpec.describe "Duitku checkout and callback", type: :request do
  let!(:configuration) do
    IntegrationSetting.new(provider: "duitku", enabled: true).tap do |record|
      record.settings = { merchant_code: "DTEST", api_key: "private-request-key", environment: "sandbox", expiry_minutes: "60" }
      record.save!
    end
  end
  let(:booking) { create(:booking, payment_method: "online_transfer") }
  let(:attempt) { create(:payment_attempt, booking: booking, provider: "duitku", gateway_environment: "sandbox", merchant_code: "DTEST", amount: booking.total_amount, transaction_id: "reference-test") }
  let(:status_response) { { "merchantOrderId" => attempt.order_id, "reference" => "reference-test", "amount" => attempt.amount.to_s, "statusCode" => "00" } }
  let(:callback) do
    fields = { merchantCode: "DTEST", merchantOrderId: attempt.order_id, amount: attempt.amount.to_s, reference: "reference-test" }
    fields[:signature] = OpenSSL::HMAC.hexdigest("SHA256", "private-request-key", "DTEST#{attempt.amount}#{attempt.order_id}")
    fields
  end

  it "rejects callback forgery and returns 200 for a verified callback without requiring a user session" do
    allow_any_instance_of(DuitkuClient).to receive(:transaction_status).and_return(status_response)
    post duitku_callback_path, params: callback.merge(signature: "wrong")
    expect(response).to have_http_status(:unprocessable_content)
    expect(attempt.reload).not_to be_paid
    post duitku_callback_path, params: callback
    expect(response).to have_http_status(:ok)
    expect(attempt.reload).to be_paid
    post duitku_callback_path, params: callback
    expect(response).to have_http_status(:ok)
  end

  it "asks Duitku to retry when the status API cannot be reached" do
    allow_any_instance_of(DuitkuClient).to receive(:transaction_status).and_raise(DuitkuClient::AmbiguousError, "timeout")
    post duitku_callback_path, params: callback
    expect(response).to have_http_status(:service_unavailable)
    expect(attempt.reload).not_to be_paid
  end

  it "never lets return URL parameters mark a booking paid" do
    sign_in booking.user
    attempt
    get booking_path(booking.reference), params: { resultCode: "00", merchantOrderId: attempt.order_id, reference: attempt.transaction_id }
    expect(response).to have_http_status(:ok)
    expect(attempt.reload).not_to be_paid
  end

  it "allows only the booking customer to create and refresh payments" do
    attempt
    sign_in create(:user)
    post booking_payment_path(booking.reference)
    expect(response).to have_http_status(:not_found)
    sign_in create(:user)
    post booking_payment_status_path(booking.reference)
    expect(response).to have_http_status(:not_found)
  end

  it "refreshes from the status API and throttles repeated manual checks" do
    sign_in booking.user
    allow_any_instance_of(DuitkuClient).to receive(:transaction_status).and_return(status_response.merge("statusCode" => "01"))
    post booking_payment_status_path(booking.reference)
    expect(response).to redirect_to(booking_path(booking.reference))
    expect(flash[:notice]).to eq(I18n.t("duitku.status_updated"))
    post booking_payment_status_path(booking.reference)
    expect(flash[:alert]).to eq(I18n.t("duitku.status_unavailable"))
    travel 31.seconds do
      allow_any_instance_of(DuitkuClient).to receive(:transaction_status).and_return(status_response)
      post booking_payment_status_path(booking.reference)
      expect(attempt.reload).to be_paid
    end
  end

  it "keeps callbacks available when admin disables new checkout" do
    configuration.update!(enabled: false)
    allow_any_instance_of(DuitkuClient).to receive(:transaction_status).and_return(status_response)
    post duitku_callback_path, params: callback
    expect(response).to have_http_status(:ok)
    expect(attempt.reload).to be_paid
  end

  it "shows encrypted Duitku configuration only to admin and preserves API Key on blank edits" do
    sign_in create(:user, :admin)
    get admin_integrations_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("/duitku/callback", 'id="duitku_api_key"')
    expect(response.body).not_to include("private-request-key")
    patch admin_integration_path(provider: "duitku"), params: { integration_setting: { enabled: "1", settings: { api_key: "", expiry_minutes: "30" } } }
    expect(response).to redirect_to(admin_integrations_path)
    expect(configuration.reload.settings).to include("api_key" => "private-request-key", "expiry_minutes" => "30")
    attempt
    patch admin_integration_path(provider: "duitku"), params: { integration_setting: { enabled: "1", settings: { api_key: "new-secret" } } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("duitku.pending_configuration"))
    expect(response.body).not_to include("new-secret", "private-request-key")
  end
end

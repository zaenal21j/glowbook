require "rails_helper"
require "openssl"

RSpec.shared_context "Duitku sandbox" do
  let!(:configuration) do
    IntegrationSetting.new(provider: "duitku", enabled: true).tap do |record|
      record.settings = { merchant_code: "DTEST", api_key: "test-private-api-key", environment: "sandbox", expiry_minutes: "60" }
      record.save!
    end
  end
  let(:booking) { create(:booking, payment_method: "online_transfer") }
  let(:attempt) { create(:payment_attempt, booking: booking, provider: "duitku", gateway_environment: "sandbox", merchant_code: "DTEST", transaction_id: "DTEST-reference", amount: booking.total_amount) }
end

RSpec.describe DuitkuClient do
  include_context "Duitku sandbox"
  let(:client) { described_class.new }
  let(:http) { double("HTTP connection") }

  def respond_with(body, response_class = Net::HTTPOK)
    response = response_class.new("1.1", response_class == Net::HTTPOK ? "200" : "503", "response")
    allow(response).to receive(:body).and_return(JSON.generate(body))
    allow(http).to receive(:request).and_return(response)
    allow(Net::HTTP).to receive(:start).and_yield(http)
  end

  it "creates a POP invoice with HMAC SHA256, trusted callbacks and the exact booking amount" do
    respond_with({ "statusCode" => "00", "reference" => "DTEST-reference", "merchantCode" => "DTEST", "paymentUrl" => "https://app-sandbox.duitku.com/redirect_checkout?reference=DTEST-reference" })
    client.create_invoice(attempt)
    expect(attempt.reload.redirect_url).to start_with("https://app-sandbox.duitku.com/")
    expect(http).to have_received(:request) do |request|
      expect(request.uri.to_s).to eq("https://api-sandbox.duitku.com/api/merchant/createInvoice")
      expected = OpenSSL::HMAC.hexdigest("SHA256", "test-private-api-key", "DTEST#{request['x-duitku-timestamp']}")
      expect(request["x-duitku-signature"]).to eq(expected)
      body = JSON.parse(request.body)
      expect(body).to include("paymentAmount" => attempt.amount, "merchantOrderId" => attempt.order_id, "expiryPeriod" => 60,
        "callbackUrl" => "http://localhost:3000/duitku/callback", "returnUrl" => "http://localhost:3000/booking/#{booking.reference}")
      expect(body["itemDetails"].sum { |item| item["price"] * item["quantity"] }).to eq(attempt.amount)
      expect(request.body).not_to include("test-private-api-key")
    end
    expect(Net::HTTP).to have_received(:start).with("api-sandbox.duitku.com", 443, use_ssl: true, open_timeout: 3, read_timeout: 5, write_timeout: 5)
  end

  it "signs status requests independently and uses the documented status endpoint" do
    respond_with({ "statusCode" => "01" })
    client.transaction_status(attempt.order_id)
    expect(http).to have_received(:request) do |request|
      expect(request.uri.to_s).to eq("https://sandbox.duitku.com/webapi/api/merchant/transactionStatus")
      expect(JSON.parse(request.body)).to include("signature" => OpenSSL::HMAC.hexdigest("SHA256", "test-private-api-key", "DTEST#{attempt.order_id}"))
    end
  end

  it "rejects foreign, HTTP, credential-bearing and unexpected-port checkout URLs" do
    ["http://app-sandbox.duitku.com/x", "https://evil.example/x", "https://app-sandbox.duitku.com.evil.example/x", "https://user@app-sandbox.duitku.com/x", "https://app-sandbox.duitku.com:8443/x", nil].each do |url|
      expect(client.valid_checkout_url?(url)).to be(false)
    end
  end

  it "keeps a rejected invoice response ambiguous so the same order can be recovered" do
    respond_with({ "statusCode" => "01", "statusMessage" => "The transaction is still in progress" })
    expect { client.create_invoice(attempt) }.to raise_error(DuitkuClient::AmbiguousError)
  end

  it "rejects a checkout response with a foreign URL" do
    respond_with({ "statusCode" => "00", "reference" => "new-reference", "paymentUrl" => "https://evil.example" })
    expect { client.create_invoice(attempt) }.to raise_error(DuitkuClient::AmbiguousError)
    expect(attempt.reload.redirect_url).to be_nil
  end

  it "does not expose gateway error response bodies or secrets" do
    respond_with({ "private" => "gateway-sensitive-value" }, Net::HTTPServiceUnavailable)
    expect { client.transaction_status(attempt.order_id) }.to raise_error(DuitkuClient::AmbiguousError) { |error| expect(error.message).not_to include("gateway-sensitive-value", "test-private-api-key") }
  end

  it "allows reconciliation when new checkout has been disabled" do
    configuration.update!(enabled: false)
    expect(described_class).not_to be_enabled
    expect { described_class.new }.to raise_error(DuitkuClient::Error)
    expect(described_class.new(allow_disabled: true).merchant_code).to eq("DTEST")
  end

  it "requires public HTTPS before production can be enabled" do
    configuration.settings = configuration.settings.merge("environment" => "production")
    expect(configuration).not_to be_valid
    allow(Rails.configuration.x).to receive(:app_host).and_return("https://glowbook.example.com")
    expect(configuration).to be_valid
    production = described_class.new(configuration: configuration)
    expect(production.valid_checkout_url?("https://app-prod.duitku.com/redirect_checkout?reference=x")).to be(true)
    expect(production.valid_checkout_url?("https://app-sandbox.duitku.com/x")).to be(false)
  end
end

RSpec.describe CreateBookingPayment do
  include_context "Duitku sandbox"
  let(:client) { instance_double(DuitkuClient, merchant_code: "DTEST", environment: "sandbox", current_configuration?: true, valid_checkout_url?: true) }

  before do
    allow(client).to receive(:create_invoice) do |payment|
      payment.update!(transaction_id: "invoice-#{payment.id}", redirect_url: "https://app-sandbox.duitku.com/redirect_checkout?reference=invoice-#{payment.id}")
    end
  end

  it "creates a Duitku attempt and reuses its checkout" do
    first = described_class.new(booking: booking, client: client).call
    expect(first).to be_ok
    expect(first.payment_attempt).to have_attributes(provider: "duitku", gateway_environment: "sandbox", merchant_code: "DTEST", amount: booking.total_amount)
    second = described_class.new(booking: booking, client: client).call
    expect(second.payment_attempt.id).to eq(first.payment_attempt.id)
    expect(client).to have_received(:create_invoice).once
  end

  it "preserves the same order after a timeout and respects a retry cooldown" do
    allow(client).to receive(:create_invoice).and_raise(DuitkuClient::AmbiguousError, "timeout")
    first = described_class.new(booking: booking, client: client).call
    expect(first.payment_attempt).to have_attributes(status: "pending", provider_status: "invoice_creation_unknown")
    expect(described_class.new(booking: booking, client: client).call).not_to be_ok
    expect(client).to have_received(:create_invoice).once
    travel 31.seconds do
      second = described_class.new(booking: booking, client: client).call
      expect(second.payment_attempt.id).to eq(first.payment_attempt.id)
      expect(second.payment_attempt.order_id).to eq(first.payment_attempt.order_id)
    end
  end

  it "refuses already paid and cancelled bookings" do
    attempt.update!(status: "settlement")
    expect(described_class.new(booking: booking, client: client).call).not_to be_ok
    booking.update!(status: :cancelled)
    expect(described_class.new(booking: booking, client: client).call).not_to be_ok
    expect(client).not_to have_received(:create_invoice)
  end

  it "retains historical pending Midtrans attempts without opening their old URL" do
    historical = create(:payment_attempt, booking: booking, provider: "midtrans", gateway_environment: nil, merchant_code: nil, amount: booking.total_amount, redirect_url: "https://app.sandbox.midtrans.com/old")
    result = described_class.new(booking: booking, client: client).call
    expect(result).not_to be_ok
    expect(result.error).to eq(I18n.t("duitku.previous_gateway"))
    expect(historical.reload.provider).to eq("midtrans")
    expect(client).not_to have_received(:create_invoice)
  end

  it "refuses stale client configuration before creating an attempt" do
    allow(client).to receive(:current_configuration?).and_return(false)
    expect { described_class.new(booking: booking, client: client).call }.not_to change(PaymentAttempt, :count)
    expect(client).not_to have_received(:create_invoice)
  end

  it "does not downgrade a concurrently confirmed payment after an invoice error" do
    allow(client).to receive(:create_invoice) do |payment|
      payment.update!(status: "settlement")
      raise DuitkuClient::Error, "error"
    end
    result = described_class.new(booking: booking, client: client).call
    expect(result.payment_attempt.reload).to be_paid
  end

  it "blocks credential and mode changes while a Duitku invoice is pending" do
    attempt
    expect(configuration.update_configuration(enabled: "1", settings: { api_key: "replacement-key" })).to be(false)
    expect(configuration.reload.settings["api_key"]).to eq("test-private-api-key")
    expect(configuration.update_configuration(enabled: "0", settings: { api_key: "" })).to be(true)
  end

  it "does not send zero-value bookings to the payment gateway" do
    booking.update!(total_amount: 0)
    expect { described_class.new(booking: booking, client: client).call }.not_to change(PaymentAttempt, :count)
    expect(client).not_to have_received(:create_invoice)
  end

  it "excludes sandbox and historical Midtrans payments from production money totals" do
    attempt.update!(status: "settlement")
    production = create(:payment_attempt, status: "settlement", amount: 123456)
    create(:payment_attempt, status: "settlement", provider: "midtrans", gateway_environment: nil, merchant_code: nil, amount: 999999)
    expect(PaymentAttempt.paid.production_payments.sum(:amount)).to eq(production.amount)
    expect(PaymentAttempt.paid.count).to eq(3)
  end
end

RSpec.describe ProcessDuitkuNotification do
  include_context "Duitku sandbox"
  let(:client) { DuitkuClient.new }
  let(:payload) do
    fields = { "merchantCode" => "DTEST", "merchantOrderId" => attempt.order_id, "amount" => attempt.amount.to_s, "reference" => attempt.transaction_id }
    fields["signature"] = OpenSSL::HMAC.hexdigest("SHA256", "test-private-api-key", "DTEST#{fields['amount']}#{attempt.order_id}")
    fields
  end
  let(:status_response) { { "merchantOrderId" => attempt.order_id, "reference" => attempt.transaction_id, "amount" => attempt.amount.to_s, "statusCode" => "00" } }
  before { allow(client).to receive(:transaction_status).with(attempt.order_id).and_return(status_response) }

  it "uses the status API to mark payment once and makes callback replay idempotent" do
    first = described_class.new(payload: payload, client: client).call
    settled_at = first.settled_at
    travel 1.minute do
      described_class.new(payload: payload, client: client).call
      expect(attempt.reload.settled_at).to eq(settled_at)
    end
    expect(attempt.reload).to be_paid
    expect(client).to have_received(:transaction_status).once
  end

  it "rejects a bad signature before requesting gateway status" do
    expect { described_class.new(payload: payload.merge("signature" => "bad"), client: client).call }.to raise_error(described_class::InvalidNotification)
    expect(client).not_to have_received(:transaction_status)
  end

  it "rejects a validly signed callback with the wrong amount" do
    bad = payload.merge("amount" => "1")
    bad["signature"] = OpenSSL::HMAC.hexdigest("SHA256", "test-private-api-key", "DTEST1#{attempt.order_id}")
    expect { described_class.new(payload: bad, client: client).call }.to raise_error(described_class::InvalidNotification)
    expect(client).not_to have_received(:transaction_status)
  end

  it "rejects wrong merchant, reference, environment and malformed payloads" do
    [{ "merchantCode" => "OTHER" }, { "reference" => "wrong" }, { "amount" => "NaN" }].each do |changes|
      expect { described_class.new(payload: payload.merge(changes), client: client).call }.to raise_error(described_class::InvalidNotification)
    end
    attempt.update!(gateway_environment: "production")
    expect { described_class.new(payload: payload, client: client).call }.to raise_error(described_class::InvalidNotification)
    expect { described_class.new(payload: {}, client: client).call }.to raise_error(described_class::InvalidNotification)
  end

  it "rejects mismatched order, reference, amount and unknown status from the status API" do
    [{ "merchantOrderId" => "other" }, { "reference" => "other" }, { "amount" => "1" }, { "statusCode" => "99" }].each do |change|
      allow(client).to receive(:transaction_status).and_return(status_response.merge(change))
      expect { described_class.new(payload: payload, client: client).call }.to raise_error(described_class::InvalidNotification)
      expect(attempt.reload).not_to be_paid
    end
  end

  it "does not trust a callback resultCode or let a late pending response regress a paid attempt" do
    allow(client).to receive(:transaction_status).and_return(status_response.merge("statusCode" => "01"))
    described_class.new(payload: payload.merge("resultCode" => "00"), client: client).call
    expect(attempt.reload).not_to be_paid
    attempt.update!(status: "settlement", settled_at: Time.current)
    described_class.new(payload: payload, client: client).call
    expect(attempt.reload).to be_paid
  end

  it "does not reopen a cancelled attempt from a pending response" do
    attempt.update!(status: "cancel")
    allow(client).to receive(:transaction_status).and_return(status_response.merge("statusCode" => "01"))
    described_class.new(payload: payload, client: client).call
    expect(attempt.reload.status).to eq("cancel")
  end
end

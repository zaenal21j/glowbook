require 'rails_helper'
require 'digest'

RSpec.describe CreateBookingPayment do
  let(:booking) { create(:booking, payment_method: "online_transfer") }
  let(:client) { instance_double(MidtransClient) }

  before { allow(client).to receive(:create_snap_transaction) }

  it "creates a Snap payment attempt and returns its checkout URL" do
    allow(client).to receive(:create_snap_transaction) do |attempt|
      attempt.update!(snap_token: "sandbox-token", redirect_url: "https://app.sandbox.midtrans.com/snap/v2/vtweb/sandbox-token")
      attempt
    end

    result = described_class.new(booking: booking, client: client).call

    expect(result).to be_ok
    expect(result.payment_attempt).to have_attributes(status: "pending", amount: booking.total_amount)
    expect(result.payment_attempt.order_id).to start_with("#{booking.reference}-")
    expect(result.payment_attempt.redirect_url).to include("sandbox-token")
  end

  it "keeps an ambiguous token request pending and retries with the same order ID after a cooldown" do
    allow(client).to receive(:create_snap_transaction).and_raise(MidtransClient::AmbiguousError, "timeout")

    first_result = described_class.new(booking: booking, client: client).call
    attempt = first_result.payment_attempt

    expect(first_result).not_to be_ok
    expect(attempt).to have_attributes(status: "pending", provider_status: "token_creation_unknown")

    second_result = described_class.new(booking: booking, client: client).call
    expect(second_result.error).to include("sedang diproses")
    expect(client).to have_received(:create_snap_transaction).once

    travel 31.seconds do
      allow(client).to receive(:create_snap_transaction) do |retried_attempt|
        expect(retried_attempt.order_id).to eq(attempt.order_id)
        retried_attempt.update!(snap_token: "retry-token", redirect_url: "https://app.sandbox.midtrans.com/snap/v2/vtweb/retry-token")
        retried_attempt
      end

      retry_result = described_class.new(booking: booking, client: client).call
      expect(retry_result).to be_ok
      expect(retry_result.payment_attempt.id).to eq(attempt.id)
    end
  end

  it "does not create another attempt after a payment has settled" do
    create(:payment_attempt, booking: booking, order_id: "#{booking.reference}-paid", amount: booking.total_amount,
                             status: "settlement", provider_status: "settlement")

    result = described_class.new(booking: booking, client: client).call

    expect(result).not_to be_ok
    expect(result.error).to include("sudah berhasil")
    expect(client).not_to have_received(:create_snap_transaction)
  end

  it "does not start a payment for a cancelled booking" do
    booking.update!(status: :cancelled)

    result = described_class.new(booking: booking, client: client).call

    expect(result).not_to be_ok
    expect(result.error).to include("tidak lagi dapat dibayar")
    expect(PaymentAttempt.where(booking: booking)).to be_empty
    expect(client).not_to have_received(:create_snap_transaction)
  end

  it "returns the configured application booking page as the Snap finish URL" do
    service = create(:service, business: booking.business)
    create(:booking_item, booking: booking, service: service, price: service.price, duration_minutes: service.duration_minutes)
    attempt = create(:payment_attempt, booking: booking, order_id: "#{booking.reference}-payload", amount: booking.total_amount)
    client = MidtransClient.new(server_key: "sandbox-test-key")

    payload = client.send(:snap_payload, attempt)

    expect(payload.dig(:callbacks, :finish)).to eq("http://localhost:3000/booking/#{booking.reference}")
  end
end

RSpec.describe ProcessMidtransNotification do
  let(:server_key) { "sandbox-test-key" }
  let(:booking) { create(:booking, payment_method: "online_transfer") }
  let(:attempt) do
    create(:payment_attempt, booking: booking, order_id: "#{booking.reference}-notify", amount: booking.total_amount)
  end
  let(:client) { instance_double(MidtransClient) }
  before { allow(client).to receive(:transaction_status) }
  let(:payload) do
    fields = {
      "order_id" => attempt.order_id,
      "status_code" => "201",
      "gross_amount" => "#{attempt.amount}.00"
    }
    fields["signature_key"] = Digest::SHA512.hexdigest("#{fields['order_id']}#{fields['status_code']}#{fields['gross_amount']}#{server_key}")
    fields
  end
  let(:settled_status) do
    {
      "order_id" => attempt.order_id,
      "gross_amount" => "#{attempt.amount}.00",
      "currency" => "IDR",
      "transaction_status" => "settlement",
      "transaction_id" => "midtrans-transaction-1",
      "payment_type" => "bank_transfer"
    }
  end

  it "trusts the current status API result and marks a settled payment once" do
    allow(client).to receive(:transaction_status).with(attempt.order_id).and_return(settled_status)

    result = described_class.new(payload: payload, client: client, server_key: server_key).call

    expect(result).to be_paid
    expect(result).to have_attributes(status: "settlement", transaction_id: "midtrans-transaction-1")
    expect(result.settled_at).to be_present
  end

  it "rejects an invalid signature without calling the status API" do
    payload["signature_key"] = "invalid"

    expect {
      described_class.new(payload: payload, client: client, server_key: server_key).call
    }.to raise_error(ProcessMidtransNotification::InvalidNotification, /Signature/)
    expect(client).not_to have_received(:transaction_status)
  end

  it "rejects an amount that does not match the saved attempt" do
    payload["gross_amount"] = "1.00"
    payload["signature_key"] = Digest::SHA512.hexdigest("#{payload['order_id']}#{payload['status_code']}#{payload['gross_amount']}#{server_key}")

    expect {
      described_class.new(payload: payload, client: client, server_key: server_key).call
    }.to raise_error(ProcessMidtransNotification::InvalidNotification, /Nominal/)
    expect(client).not_to have_received(:transaction_status)
  end

  it "rejects an unexpected currency from the status API" do
    allow(client).to receive(:transaction_status).with(attempt.order_id).and_return(settled_status.merge("currency" => "USD"))

    expect {
      described_class.new(payload: payload, client: client, server_key: server_key).call
    }.to raise_error(ProcessMidtransNotification::InvalidNotification, /Mata uang/)
  end

  it "does not treat a captured transaction with a denied fraud status as paid" do
    status = settled_status.merge("transaction_status" => "capture", "fraud_status" => "deny")
    allow(client).to receive(:transaction_status).with(attempt.order_id).and_return(status)

    result = described_class.new(payload: payload, client: client, server_key: server_key).call

    expect(result.status).to eq("deny")
    expect(result).not_to be_paid
  end
end

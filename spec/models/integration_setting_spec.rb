require "rails_helper"

RSpec.describe IntegrationSetting, type: :model do
  let(:record) { described_class.new(provider: "google_oauth2", enabled: true) }

  it "encrypts credentials at rest and preserves blank secrets during updates" do
    record.settings = { client_id: "test-client", client_secret: "original-private-secret" }
    record.save!
    expect(record.reload.encrypted_settings).not_to include("original-private-secret", "test-client")
    expect(record.settings["client_secret"]).to eq("original-private-secret")
    expect(record.update_configuration(enabled: "1", settings: { client_id: "replacement-client", client_secret: "" })).to be(true)
    expect(record.reload.settings).to include("client_id" => "replacement-client", "client_secret" => "original-private-secret")
    record.update_configuration(enabled: "1", settings: { client_secret: "rotated-secret" })
    expect(record.reload.settings["client_secret"]).to eq("rotated-secret")
  end

  it "requires complete credentials only when enabled" do
    record.settings = { client_id: "test-client" }
    expect(record).not_to be_valid
    record.enabled = false
    expect(record).to be_valid
  end

  it "removes a saved secret only with an explicit request" do
    record.settings = { client_id: "test-client", client_secret: "private-secret" }
    record.save!
    expect(record.update_configuration(enabled: "0", clear_secret: "1", settings: { client_secret: "" })).to be(true)
    expect(record.reload.settings).not_to have_key("client_secret")
    expect(record).not_to be_ready
  end

  it "binds ciphertext to its provider" do
    record.settings = { client_id: "test-client", client_secret: "secret" }
    record.provider = "facebook"
    expect { record.settings }.to raise_error(ActiveSupport::MessageEncryptor::InvalidMessage)
  end

  it "allows a saved disabled integration to override environment credentials" do
    expect(described_class.effective("facebook")).to be_ready
    described_class.create!(provider: "facebook", enabled: false)
    expect(described_class.effective("facebook")).not_to be_ready
  end

  it "validates SMTP settings and enforces encrypted transport" do
    smtp = described_class.new(provider: "smtp", enabled: true)
    smtp.settings = { address: "smtp.example.com", port: "587", from: "hello@example.com", tls_mode: "starttls", username: "mailer", password: "smtp-secret" }
    expect(smtp).to be_valid
    expect(smtp.smtp_options).to include(enable_starttls: true, openssl_verify_mode: OpenSSL::SSL::VERIFY_PEER, authentication: :plain)
    smtp.settings = smtp.settings.merge("port" => "70000")
    expect(smtp).not_to be_valid
    smtp.settings = smtp.settings.merge("port" => "465", "tls_mode" => "tls", "password" => "")
    expect(smtp).not_to be_valid
    smtp.settings = smtp.settings.merge("username" => "")
    expect(smtp).to be_valid
    expect(smtp.smtp_options).to include(tls: true)
    expect(smtp.smtp_options).not_to have_key(:enable_starttls)
  end

  it "filters integration settings from request logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    expect(filter.filter("integration_setting" => { "settings" => { "client_secret" => "private" } })).to eq("integration_setting" => "[FILTERED]")
  end
end

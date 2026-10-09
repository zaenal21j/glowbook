require "rails_helper"

RSpec.describe OauthProviderSetup do
  it "uses saved credentials and the canonical callback on each request" do
    record = IntegrationSetting.new(provider: "google_oauth2", enabled: true)
    record.settings = { client_id: "first-id", client_secret: "first-secret" }
    record.save!
    strategy = Struct.new(:options).new({})
    described_class.call({ "omniauth.strategy" => strategy }, "google_oauth2")
    expect(strategy.options).to include(client_id: "first-id", client_secret: "first-secret",
      redirect_uri: "#{Rails.configuration.x.app_host.chomp('/')}/users/auth/google_oauth2/callback")
    record.update_configuration(enabled: "1", settings: { client_id: "new-id", client_secret: "new-secret" })
    described_class.call({ "omniauth.strategy" => strategy }, "google_oauth2")
    expect(strategy.options[:client_secret]).to eq("new-secret")
    record.update!(enabled: false)
    expect { described_class.call({ "omniauth.strategy" => strategy }, "google_oauth2") }.to raise_error(OmniAuth::Error, "provider_not_configured")
  end

  it "sets Facebook's callback URL explicitly too" do
    strategy = Struct.new(:options).new({})
    described_class.call({ "omniauth.strategy" => strategy }, "facebook")
    expect(strategy.options[:callback_url]).to eq("#{Rails.configuration.x.app_host.chomp('/')}/users/auth/facebook/callback")
  end
end

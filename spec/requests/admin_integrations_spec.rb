require "rails_helper"

RSpec.describe "Admin integrations", type: :request do
  let(:configuration) { { enabled: "1", settings: { client_id: "google-admin-id", client_secret: "never-echo-this-secret" } } }

  it "denies reads and changes by guests and customers" do
    get admin_integrations_path
    expect(response).to redirect_to(login_path)
    expect { patch admin_integration_path(provider: "google_oauth2"), params: { integration_setting: configuration } }.not_to change(IntegrationSetting, :count)
    sign_in create(:user)
    get admin_integrations_path
    expect(response).to redirect_to(root_path)
    expect { patch admin_integration_path(provider: "google_oauth2"), params: { integration_setting: configuration } }.not_to change(IntegrationSetting, :count)
    expect(response).to redirect_to(root_path)
  end

  it "saves encrypted credentials, renders blank secrets and preserves them on later edits" do
    sign_in create(:user, :admin)
    patch admin_integration_path(provider: "google_oauth2"), params: { integration_setting: configuration }
    expect(response).to redirect_to(admin_integrations_path)
    integration = IntegrationSetting.find_by!(provider: "google_oauth2")
    expect(integration.settings["client_secret"]).to eq("never-echo-this-secret")
    expect(integration.encrypted_settings).not_to include("never-echo-this-secret")
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("never-echo-this-secret")
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('#google_oauth2_client_secret')["value"]).to be_blank
    expect(document.at_css('#google_oauth2_client_id')["value"]).to eq("google-admin-id")
    expect(response.body).to include("#{Rails.configuration.x.app_host.chomp('/')}/users/auth/google_oauth2/callback")
    patch admin_integration_path(provider: "google_oauth2"), params: { integration_setting: { enabled: "0", settings: { client_id: "updated-id", client_secret: "" } } }
    expect(integration.reload).not_to be_enabled
    expect(integration.settings["client_secret"]).to eq("never-echo-this-secret")
  end

  it "renders validation errors without echoing submitted secrets" do
    sign_in create(:user, :admin)
    patch admin_integration_path(provider: "google_oauth2"), params: { integration_setting: { enabled: "1", settings: { client_id: "", client_secret: "invalid-form-secret" } } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).not_to include("invalid-form-secret", "Translation missing")
    expect(IntegrationSetting.count).to eq(0)
  end

  it "renders configuration in both languages and rejects unknown providers" do
    sign_in create(:user, :admin)
    %w[id en].each do |locale|
      post locale_path(locale)
      get admin_integrations_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to match(/translation missing/i)
      expect(response.body).to include(I18n.t("integrations.providers.google_oauth2", locale: locale))
    end
    patch admin_integration_path(provider: "unknown"), params: { integration_setting: configuration }
    expect(response).to have_http_status(:not_found)
  end
end

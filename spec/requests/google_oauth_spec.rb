require "rails_helper"

RSpec.describe "Google OAuth", type: :request do
  let(:auth_hash) do
    OmniAuth::AuthHash.new(provider: "google_oauth2", uid: "google-123",
      info: { email: "google-user@example.com", email_verified: true, name: "Budi Google" })
  end

  before do
    host! URI(Rails.configuration.x.app_host).authority
    IntegrationSetting.new(provider: "google_oauth2", enabled: true).tap do |record|
      record.settings = { client_id: "google-test-id", client_secret: "google-test-secret" }
      record.save!
    end
    get login_path
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = auth_hash
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:google_oauth2)
  end

  it "creates a customer with a verified email" do
    expect { google_sign_in }.to change(User, :count).by(1)
    expect(response).to redirect_to(account_root_path)
    user = User.find_by!(provider: "google_oauth2", uid: "google-123")
    expect(user).to be_customer
    expect(user.email).to eq("google-user@example.com")
  end

  it "keeps the identity and existing role when signing in again" do
    user = create(:user, :admin, provider: "google_oauth2", uid: "google-123", email: auth_hash.info.email)
    expect { google_sign_in }.not_to change(User, :count)
    expect(response).to redirect_to(admin_root_path)
    expect(user.reload).to be_admin
  end

  it "does not link an existing password account by email" do
    user = create(:user, email: auth_hash.info.email)
    expect { google_sign_in }.not_to change(User, :count)
    expect(response).to redirect_to(login_path)
    expect(user.reload.provider).to be_nil
    expect(flash[:alert]).to eq(I18n.t("integrations.account_conflict"))
  end

  it "rejects unverified and malformed identities" do
    [false, "false", nil].each do |verified|
      auth_hash.info.email_verified = verified
      expect { google_sign_in }.not_to change(User, :count)
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq(I18n.t("integrations.google_unverified"))
    end
    auth_hash.info.email_verified = true
    auth_hash.uid = ""
    expect { google_sign_in }.not_to change(User, :count)
  end

  it "handles a cancelled authorization" do
    OmniAuth.config.mock_auth[:google_oauth2] = :access_denied
    google_sign_in
    expect(response).to redirect_to(login_path)
    expect(flash[:alert]).to eq(I18n.t("integrations.oauth_failed"))
  end

  it "hides disabled providers from both account forms and refuses authorization" do
    IntegrationSetting.find_by!(provider: "google_oauth2").update!(enabled: false)
    [login_path, signup_path].each do |path|
      get path
      expect(response.body).not_to include('action="/users/auth/google_oauth2"')
    end
    expect { post user_google_oauth2_omniauth_authorize_path }.not_to change(User, :count)
    follow_redirect! if response.location&.include?("/users/auth/failure")
    expect(response).to redirect_to(login_path)
  end

  it "renders Google as a POST form on login and registration" do
    [login_path, signup_path].each do |path|
      get path
      form = Nokogiri::HTML(response.body).at_css('form[action="/users/auth/google_oauth2"]')
      expect(form["method"]).to eq("post")
      expect(form.at_css('button')["data-turbo"]).to eq("false")
    end
  end

  it "starts real middleware authorization with CSRF, state and the canonical callback" do
    OmniAuth.config.test_mode = false
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get login_path
    form = Nokogiri::HTML(response.body).at_css('form[action="/users/auth/google_oauth2"]')
    token = form.at_css('input[name="authenticity_token"]')["value"]
    post user_google_oauth2_omniauth_authorize_path, params: { authenticity_token: token }
    uri = URI(response.location)
    query = URI.decode_www_form(uri.query).to_h
    expect(uri.host).to eq("accounts.google.com")
    expect(query).to include("client_id" => "google-test-id", "redirect_uri" => "#{Rails.configuration.x.app_host.chomp('/')}/users/auth/google_oauth2/callback", "access_type" => "online")
    expect(query["state"]).to be_present
    expect(response.location).not_to include("google-test-secret")
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  it "rejects a real authorization request without a CSRF token" do
    OmniAuth.config.test_mode = false
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    post user_google_oauth2_omniauth_authorize_path
    expect(response).to have_http_status(:unprocessable_content)
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  it "refuses callbacks with an invalid state before contacting Google" do
    OmniAuth.config.test_mode = false
    post user_google_oauth2_omniauth_authorize_path
    expect(URI(response.location).host).to eq("accounts.google.com")
    expect { get user_google_oauth2_omniauth_callback_path, params: { state: "wrong-state", code: "fake-code" } }.not_to change(User, :count)
    expect(response).to redirect_to(login_path)
    expect(flash[:alert]).to eq(I18n.t("integrations.oauth_failed"))
  end

  private

  def google_sign_in
    post user_google_oauth2_omniauth_authorize_path
    expect(response).to redirect_to(user_google_oauth2_omniauth_callback_path)
    follow_redirect!
  end
end

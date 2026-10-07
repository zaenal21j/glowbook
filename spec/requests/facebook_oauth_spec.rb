require 'rails_helper'

RSpec.describe "Facebook OAuth", type: :request do
  let(:auth_hash) do
    OmniAuth::AuthHash.new(
      provider: "facebook",
      uid: "1234567890",
      info: { email: "fb-user@example.com", name: "Budi FB", image: "https://example.com/a.jpg" }
    )
  end

  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:facebook] = auth_hash
    # Request specs memakai rack-test (tanpa session Rails asli);
    # matikan CSRF proteksi OmniAuth di lingkungan test.
    OmniAuth.config.allowed_request_methods = [ :get, :post ]
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:facebook)
    OmniAuth.config.allowed_request_methods = [ :post ]
  end

  it "creates a new user on first login" do
    expect do
      post "/users/auth/facebook/callback"
    end.to change(User, :count).by(1)

    user = User.find_by(uid: "1234567890", provider: "facebook")
    expect(user).to be_present
    expect(user.email).to eq("fb-user@example.com")
    expect(user.role).to eq("customer")
    expect([ 302, 303 ]).to include(response.status)
  end

  it "signs in the same user on subsequent logins" do
    post "/users/auth/facebook/callback"
    expect do
      delete "/keluar"
      post "/users/auth/facebook/callback"
    end.not_to change(User, :count)
  end

  it "redirects to login with a friendly message on failure" do
    OmniAuth.config.mock_auth[:facebook] = :invalid_credentials
    post "/users/auth/facebook/callback"
    expect(response).to redirect_to("/masuk")
  end
end

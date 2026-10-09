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
    get login_path
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:facebook] = auth_hash
    OmniAuth.config.allowed_request_methods = [ :post ]
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:facebook)
    OmniAuth.config.allowed_request_methods = [ :post ]
  end

  it "creates a new user on first login" do
    expect do
      facebook_sign_in
    end.to change(User, :count).by(1)

    user = User.find_by(uid: "1234567890", provider: "facebook")
    expect(user).to be_present
    expect(user.email).to eq("fb-user@example.com")
    expect(user.role).to eq("customer")
    expect([ 302, 303 ]).to include(response.status)
  end

  it "signs in the same user on subsequent logins" do
    facebook_sign_in
    user = User.find_by!(uid: "1234567890", provider: "facebook")
    expect do
      delete "/keluar"
      facebook_sign_in
    end.not_to change(User, :count)
    expect(response).to redirect_to(account_root_path)
    expect(User.find_by!(uid: "1234567890", provider: "facebook").id).to eq(user.id)
  end

  it "redirects to login with a friendly message on failure" do
    OmniAuth.config.mock_auth[:facebook] = :invalid_credentials
    facebook_sign_in
    expect(response).to redirect_to("/masuk")
  end

  it "handles an email already registered with a password without taking over the account" do
    existing = create(:user, email: auth_hash.info.email)
    expect { facebook_sign_in }.not_to change(User, :count)
    expect(response).to redirect_to(login_path)
    expect(existing.reload.provider).to be_nil
  end

  private

  def facebook_sign_in
    post user_facebook_omniauth_authorize_path
    expect(response).to redirect_to(user_facebook_omniauth_callback_path)
    follow_redirect!
  end
end

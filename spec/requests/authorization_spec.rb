require 'rails_helper'

RSpec.describe "Authorization", type: :request do
  let(:customer) { create(:user) }
  let(:owner)    { create(:user, :owner) }
  let(:business) { create(:business, owner: owner) }

  describe "customer dashboard" do
    it "redirects guests to login" do
      get "/akun"
      assert_redirected_to_login
    end

    it "allows customers" do
      sign_in customer
      get "/akun"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "business dashboard" do
    it "blocks guests" do
      get "/bisnis"
      assert_redirected_to_login
    end

    it "blocks customers" do
      sign_in customer
      get "/bisnis"
      expect(response).to redirect_to(root_path)
    end

    it "allows the owner of a registered business" do
      business # buat bisnis milik owner
      sign_in owner
      get "/bisnis"
      expect(response).to have_http_status(:ok)
    end

    it "blocks owners of other businesses from editing services" do
      other_owner = create(:user, :owner)
      service = create(:service, business: business)
      sign_in other_owner

      get edit_dashboard_manage_service_path(service)

      # 404 langsung, atau redirect dengan alert "tidak memiliki akses"
      expect([404, 302]).to include(response.status)
      expect(response.body).not_to include("Formulir") if response.status == 200
    end
  end

  describe "admin area" do
    it "blocks guests" do
      get "/admin"
      assert_redirected_to_login
    end

    it "blocks business owners" do
      sign_in owner
      get "/admin"
      expect(response).to redirect_to(root_path)
    end

    it "allows admins" do
      sign_in create(:user, :admin)
      get "/admin"
      expect(response).to have_http_status(:ok)
    end
  end

  def assert_redirected_to_login
    expect(response).to have_http_status(:redirect)
    expect(response.location).to include("masuk")
  end

  private

  def sign_in(user)
    post "/users/masuk", params: { user: { email: user.email, password: "password123" } }
  end
end

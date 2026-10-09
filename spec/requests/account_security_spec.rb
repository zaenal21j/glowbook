require "rails_helper"

RSpec.describe "Account password security", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }

  around do |example|
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    ActionMailer::Base.deliveries.clear
    clear_enqueued_jobs
    example.run
  ensure
    clear_enqueued_jobs
    ActionMailer::Base.deliveries.clear
    ActiveJob::Base.queue_adapter = adapter
  end

  def reset_mail
    perform_enqueued_jobs
    ActionMailer::Base.deliveries.find { |mail| mail.html_part&.body&.decoded&.include?("reset_password_token=") }
  end

  def reset_token(mail)
    url = Nokogiri::HTML(mail.html_part.body.decoded).at_css("a")["href"]
    URI.decode_www_form(URI(url).query).to_h.fetch("reset_password_token")
  end

  it "opens a password form from signed-in settings and keeps the session after changing password" do
    sign_in user
    get account_settings_path
    expect(Nokogiri::HTML(response.body).css("a").map { |a| a["href"] }).to include(account_password_path)
    get account_password_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('autocomplete="current-password"', 'autocomplete="new-password"')
    patch account_password_path, params: { user: { current_password: "password123", password: "changed-password-123", password_confirmation: "changed-password-123", role: "admin" } }
    expect(response).to redirect_to(account_settings_path)
    expect(user.reload.valid_password?("changed-password-123")).to be(true)
    expect(user).to be_customer
    get account_settings_path
    expect(response).to have_http_status(:ok)
    perform_enqueued_jobs
    expect(ActionMailer::Base.deliveries.sole.to).to eq([user.email])
    expect(ActionMailer::Base.deliveries.sole.text_part.body.decoded).to include(I18n.t("account_email.password_changed"))
  end

  it "refuses an incorrect current password and never echoes password fields" do
    sign_in user
    patch account_password_path, params: { user: { current_password: "incorrect-secret", password: "changed-password-123", password_confirmation: "changed-password-123" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.valid_password?("password123")).to be(true)
    expect(response.body).not_to include('value="incorrect-secret"', 'value="changed-password-123"')
    expect(enqueued_jobs).to be_empty
  end

  it "rejects blank, short, and mismatched new passwords" do
    sign_in user
    [["", ""], ["short", "short"], ["changed-password-123", "different-password"]].each do |password, confirmation|
      patch account_password_path, params: { user: { current_password: "password123", password: password, password_confirmation: confirmation } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?("password123")).to be(true)
    end
    expect(enqueued_jobs).to be_empty
  end

  it "requires authentication for both password endpoints" do
    get account_password_path
    expect(response).to redirect_to(new_user_session_path)
    patch account_password_path, params: { user: { password: "changed-password-123" } }
    expect(response).to redirect_to(new_user_session_path)
  end

  it "allows owners and administrators to change only their own password" do
    [create(:user, :owner), create(:user, :admin)].each do |member|
      create(:business, owner: member) unless member.admin?
      sign_in member
      get(member.admin? ? admin_settings_path : dashboard_settings_path)
      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).css("a").map { |a| a["href"] }).to include(account_password_path)
      get account_password_path
      expect(response).to have_http_status(:ok)
      patch account_password_path, params: { id: user.id, user: { current_password: "password123", password: "changed-password-123", password_confirmation: "changed-password-123" } }
      expect(member.reload.valid_password?("changed-password-123")).to be(true)
      expect(user.reload.valid_password?("password123")).to be(true)
    end
  end

  it "queues localized reset instructions and accepts the real token once" do
    post user_password_path, params: { user: { email: user.email } }
    expect(response).to redirect_to(new_user_session_path)
    expect(ActionMailer::Base.deliveries).to be_empty
    expect(enqueued_jobs.sole[:job]).to eq(BookingMailerDeliveryJob)
    expect(BookingMailerDeliveryJob.log_arguments).to be(false)
    mail = reset_mail
    expect(mail.to).to eq([user.email])
    expect(mail.from).to eq([ENV.fetch("MAILER_FROM", "no-reply@glowbook.id")])
    expect(mail.text_part.body.decoded).to include("berlaku selama 6 jam")
    token = reset_token(mail)
    get edit_user_password_path(reset_password_token: token)
    expect(response).to have_http_status(:ok)
    patch user_password_path, params: { user: { reset_password_token: token, password: "reset-password-123", password_confirmation: "reset-password-123" } }
    expect(user.reload.valid_password?("reset-password-123")).to be(true)
    expect(user.reset_password_token).to be_nil
    get account_settings_path
    expect(response).to have_http_status(:ok)
    delete destroy_user_session_path
    patch user_password_path, params: { user: { reset_password_token: token, password: "reused-token-password", password_confirmation: "reused-token-password" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.valid_password?("reset-password-123")).to be(true)
  end

  it "keeps the requested English locale while the queued mail is delivered later" do
    post locale_path(:en)
    post user_password_path, params: { user: { email: user.email } }
    expect(ActionMailer::Base.deliveries).to be_empty
    mail = I18n.with_locale(:id) { reset_mail }
    expect(mail.text_part.body.decoded).to include("This link expires in 6 hours")
    expect(mail.text_part.body.decoded).not_to include("berlaku selama 6 jam")
  end

  it "gives the same response for registered and unknown reset email addresses" do
    notices = [user.email, "unknown@example.com"].map do |email|
      post user_password_path, params: { user: { email: email } }
      expect(response).to have_http_status(:see_other)
      follow_redirect!
      Nokogiri::HTML(response.body).at_css(".bg-emerald-50").text.strip
    end
    expect(notices.first).to eq(notices.last)
    expect(notices.first).to include(I18n.t("devise.passwords.send_paranoid_instructions"))
    expect(enqueued_jobs.size).to eq(1)
  end

  it "rejects expired and forged reset tokens" do
    token = user.send_reset_password_instructions
    user.update_column(:reset_password_sent_at, 7.hours.ago)
    [token, "invalid-token"].each do |value|
      patch user_password_path, params: { user: { reset_password_token: value, password: "reset-password-123", password_confirmation: "reset-password-123" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.valid_password?("password123")).to be(true)
    end
  end

  it "requires the current password before changing the sign-in email" do
    sign_in user
    original_email = user.email
    patch account_profile_path, params: { user: { email: "new@example.com", current_password: "wrong", role: "admin" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.email).to eq(original_email)
    expect(enqueued_jobs).to be_empty
    patch account_profile_path, params: { user: { email: "new@example.com", current_password: "password123", role: "admin" } }
    expect(response).to redirect_to(account_profile_path)
    expect(user.reload.email).to eq("new@example.com")
    expect(user).to be_customer
    perform_enqueued_jobs
    expect(ActionMailer::Base.deliveries.sole.to).to eq([original_email])
    expect(ActionMailer::Base.deliveries.sole.text_part.body.decoded).to include("new@example.com")
  end

  it "updates ordinary profile fields without requiring a password or accepting a new one" do
    sign_in user
    patch account_profile_path, params: { user: { name: "Updated name", phone: "081234567890", email: user.email, password: "injected-password", role: "admin" } }
    expect(response).to redirect_to(account_profile_path)
    expect(user.reload.name).to eq("Updated name")
    expect(user.valid_password?("password123")).to be(true)
    expect(user).to be_customer
    expect(enqueued_jobs).to be_empty
  end
end

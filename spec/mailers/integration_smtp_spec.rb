require "rails_helper"

RSpec.describe "Dynamic SMTP delivery" do
  let(:user) { create(:user) }

  after { ActionMailer::Base.deliveries.clear }

  it "keeps the current delivery adapter when SMTP has no saved override" do
    message = Devise.mailer.reset_password_instructions(user, "test-token").deliver_now
    expect(message.delivery_method).to be_a(Mail::TestMailer)
    expect(ActionMailer::Base.deliveries).to include(message)
  end

  it "applies saved SMTP to Devise mail without restarting or opening a network connection" do
    record = IntegrationSetting.new(provider: "smtp", enabled: true)
    record.settings = { address: "smtp.example.com", port: "465", username: "mailer", password: "private-smtp-secret", from: "hello@example.com", tls_mode: "tls" }
    record.save!
    allow(Devise.mailer).to receive(:perform_deliveries).and_return(false)
    delivered = []
    allow_any_instance_of(Mail::SMTP).to receive(:deliver!) { |smtp, message| delivered << [smtp.settings, message.from] }
    Devise.mailer.reset_password_instructions(user, "test-token").deliver_now
    expect(delivered.sole[0]).to include(address: "smtp.example.com", port: 465, password: "private-smtp-secret", tls: true)
    expect(delivered.sole[1]).to eq(["hello@example.com"])
    record.update_configuration(enabled: "1", settings: { from: "updated@example.com" })
    Devise.mailer.reset_password_instructions(user, "test-token").deliver_now
    expect(delivered.last[1]).to eq(["updated@example.com"])
  end

  it "disables delivery when the admin turns SMTP off" do
    IntegrationSetting.create!(provider: "smtp", enabled: false)
    expect { Devise.mailer.reset_password_instructions(user, "test-token").deliver_now }.not_to change(ActionMailer::Base.deliveries, :count)
  end
end

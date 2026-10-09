# Devise configuration for GlowBook
Devise.setup do |config|
  config.mailer_sender = ENV.fetch("MAILER_FROM", "no-reply@glowbook.id")

  require "devise/orm/active_record"

  # ==> Controller configuration
  config.parent_controller = "ApplicationController"
  config.parent_mailer = "ApplicationMailer"

  # ==> Model configuration
  # (Extra permitted params are whitelisted in ApplicationController)

  # ==> Configure the parent action for password reset emails
  config.reset_password_within = 6.hours
  config.paranoid = true
  config.send_password_change_notification = true
  config.send_email_changed_notification = true

  # ==> OmniAuth
  facebook_app_id = ENV["FACEBOOK_APP_ID"]
  facebook_app_secret = ENV["FACEBOOK_APP_SECRET"]
  if facebook_app_id.present? && facebook_app_secret.present?
    config.omniauth :facebook, facebook_app_id, facebook_app_secret,
                   scope: "email,public_profile", info_fields: "email,name", image_size: "large"
  end

  # ==> Controller configuration
  config.sign_out_via = :delete

  # ==> Password length
  config.password_length = 8..128

  # ==> Email regexp
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/

  # ==> Navigation
  config.navigational_formats = ["*/*", :html, :turbo_stream]
  config.responder.error_status = :unprocessable_content
  config.responder.redirect_status = :see_other
end

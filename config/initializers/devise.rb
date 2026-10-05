# Devise configuration for GlowBook
Devise.setup do |config|
  config.mailer_sender = "no-reply@glowbook.id"

  require "devise/orm/active_record"

  # ==> Controller configuration
  config.parent_controller = "ApplicationController"
  config.parent_mailer = "ApplicationMailer"

  # ==> Model configuration
  # (Extra permitted params are whitelisted in ApplicationController)

  # ==> Configure the parent action for password reset emails
  config.reset_password_within = 6.hours

  # ==> OmniAuth
  config.omniauth :facebook, ENV["FACEBOOK_APP_ID"], ENV["FACEBOOK_APP_SECRET"],
                 scope: "email,public_profile", info_fields: "email,name", image_size: "large"

  # ==> Controller configuration
  config.sign_out_via = :delete

  # ==> Password length
  config.password_length = 8..128

  # ==> Email regexp
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/

  # ==> Navigation
  config.navigational_formats = ["*/*", :html, :turbo_stream]
end

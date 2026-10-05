require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Glowbook
  class Application < Rails::Application
    config.load_defaults 8.1

    # Please, add to the `config.ignore_models` any models you want to omit
    config.autoloader = :zeitwerk

    # Set default locale & timezone for Indonesian marketplace
    config.i18n.default_locale = :id
    config.i18n.available_locales = %i[id en]
    config.time_zone = "Jakarta"
    config.active_record.default_timezone = :utc

    # Devise: allow routing via OmniAuth
    config.x.facebook_enabled = ENV["FACEBOOK_APP_ID"].present?
    config.x.app_host = ENV.fetch("APP_HOST", "http://localhost:3000")

    # Allow access by IP in development (localhost is default)
    config.hosts << "127.0.0.1" if Rails.env.development?
  end
end

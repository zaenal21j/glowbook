class IntegrationSetting < ApplicationRecord
  PROVIDERS = %w[google_oauth2 facebook smtp].freeze
  FIELDS = {
    "google_oauth2" => %w[client_id client_secret],
    "facebook" => %w[client_id client_secret],
    "smtp" => %w[address port username password from tls_mode]
  }.freeze
  SECRET_FIELDS = %w[client_secret password].freeze

  validates :provider, inclusion: { in: PROVIDERS }, uniqueness: true
  validates :enabled, inclusion: { in: [true, false] }
  validate :validate_configuration, if: :enabled?

  def self.effective(provider)
    find_by(provider: provider) || new(provider: provider).tap do |record|
      values = case provider
      when "google_oauth2" then { client_id: ENV["GOOGLE_CLIENT_ID"], client_secret: ENV["GOOGLE_CLIENT_SECRET"] }
      when "facebook" then { client_id: ENV["FACEBOOK_APP_ID"], client_secret: ENV["FACEBOOK_APP_SECRET"] }
      when "smtp" then { address: ENV["SMTP_ADDRESS"], port: ENV["SMTP_ADDRESS"].present? ? ENV.fetch("SMTP_PORT", "587") : "587", username: ENV["SMTP_USERNAME"], password: ENV["SMTP_PASSWORD"], from: ENV.fetch("MAILER_FROM", "no-reply@glowbook.id"), tls_mode: "starttls" }
      else raise ArgumentError, "Unknown integration"
      end
      record.settings = values
      record.enabled = provider == "smtp" ? values[:address].present? : values.values.all?(&:present?)
    end
  end

  def settings
    return {} if encrypted_settings.blank?

    values = encryptor.decrypt_and_verify(encrypted_settings, purpose: "integration/#{provider}")
    raise ActiveSupport::MessageEncryptor::InvalidMessage unless values.is_a?(Hash)

    values
  end

  def settings=(values)
    values = values.stringify_keys.slice(*FIELDS.fetch(provider))
    self.encrypted_settings = encryptor.encrypt_and_sign(values, purpose: "integration/#{provider}")
  end

  def update_configuration(attributes)
    values = attributes.to_h.deep_stringify_keys
    submitted = values.fetch("settings", {}).slice(*FIELDS.fetch(provider))
    SECRET_FIELDS.each { |field| submitted.delete(field) if submitted[field].blank? }
    previous = settings
    SECRET_FIELDS.each { |field| previous.delete(field) } if ActiveModel::Type::Boolean.new.cast(values["clear_secret"])
    self.settings = previous.merge(submitted)
    self.enabled = ActiveModel::Type::Boolean.new.cast(values["enabled"])
    save
  end

  def ready?
    enabled? && valid?
  end

  def smtp_options
    values = settings
    options = { address: values["address"], port: values["port"].to_i,
      open_timeout: 10, read_timeout: 10, openssl_verify_mode: OpenSSL::SSL::VERIFY_PEER }
    options.merge!(values["tls_mode"] == "tls" ? { tls: true } : { enable_starttls: true })
    options.merge!(user_name: values["username"], password: values["password"], authentication: :plain) if values["username"].present?
    options
  end

  private

  def encryptor
    key = Rails.application.key_generator.generate_key("glowbook-integration-settings-v1", 32)
    ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
  end

  def validate_configuration
    values = settings
    required = provider == "smtp" ? %w[address port from tls_mode] : %w[client_id client_secret]
    required.each { |field| errors.add(:base, I18n.t("integrations.missing_field", field: I18n.t("integrations.fields.#{field}"))) if values[field].blank? }
    return unless provider == "smtp"

    errors.add(:base, I18n.t("integrations.invalid_smtp")) unless values["port"].to_s.match?(/\A\d+\z/) && (1..65535).cover?(values["port"].to_i) &&
      values["address"].to_s.match?(/\A[a-zA-Z0-9.\-:]+\z/) && values["from"].to_s.match?(Devise.email_regexp) && %w[starttls tls].include?(values["tls_mode"])
    if values["username"].present? != values["password"].present?
      errors.add(:base, I18n.t("integrations.smtp_credentials_pair"))
    end
  end
end

class IntegrationSetting < ApplicationRecord
  PROVIDERS = %w[google_oauth2 facebook smtp duitku].freeze
  FIELDS = {
    "google_oauth2" => %w[client_id client_secret],
    "facebook" => %w[client_id client_secret],
    "smtp" => %w[address port username password from tls_mode],
    "duitku" => %w[merchant_code api_key environment expiry_minutes]
  }.freeze
  SECRET_FIELDS = %w[client_secret password api_key].freeze

  validates :provider, inclusion: { in: PROVIDERS }, uniqueness: true
  validates :enabled, inclusion: { in: [true, false] }
  validate :validate_configuration, if: :enabled?

  def self.effective(provider)
    find_by(provider: provider) || new(provider: provider).tap do |record|
      values = case provider
      when "google_oauth2" then { client_id: ENV["GOOGLE_CLIENT_ID"], client_secret: ENV["GOOGLE_CLIENT_SECRET"] }
      when "facebook" then { client_id: ENV["FACEBOOK_APP_ID"], client_secret: ENV["FACEBOOK_APP_SECRET"] }
      when "smtp" then { address: ENV["SMTP_ADDRESS"], port: ENV["SMTP_ADDRESS"].present? ? ENV.fetch("SMTP_PORT", "587") : "587", username: ENV["SMTP_USERNAME"], password: ENV["SMTP_PASSWORD"], from: ENV.fetch("MAILER_FROM", "no-reply@glowbook.id"), tls_mode: "starttls" }
      when "duitku" then { merchant_code: ENV["DUITKU_MERCHANT_CODE"], api_key: ENV["DUITKU_API_KEY"], environment: ENV.fetch("DUITKU_ENVIRONMENT", "sandbox"), expiry_minutes: ENV.fetch("DUITKU_EXPIRY_MINUTES", "60") }
      else raise ArgumentError, "Unknown integration"
      end
      record.settings = values
      record.enabled = case provider
      when "smtp" then values[:address].present?
      when "duitku" then ENV["DUITKU_ENABLED"] == "true"
      else values.values.all?(&:present?)
      end
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
    return assign_configuration(attributes) unless provider == "duitku"

    self.class.with_duitku_lock do
      reload if persisted?
      assign_configuration(attributes)
    end
  end

  def self.with_duitku_lock
    transaction do
      connection.execute("SELECT pg_advisory_xact_lock(42970010)")
      yield
    end
  end

  def assign_configuration(attributes)
    values = attributes.to_h.deep_stringify_keys
    submitted = values.fetch("settings", {}).slice(*FIELDS.fetch(provider))
    SECRET_FIELDS.each { |field| submitted.delete(field) if submitted[field].blank? }
    previous = settings
    original = previous.dup
    SECRET_FIELDS.each { |field| previous.delete(field) } if ActiveModel::Type::Boolean.new.cast(values["clear_secret"])
    updated = previous.merge(submitted)
    if provider == "duitku" && original.slice("merchant_code", "api_key", "environment") != updated.slice("merchant_code", "api_key", "environment") && PaymentAttempt.where(provider: "duitku", status: "pending").exists?
      errors.add(:base, I18n.t("duitku.pending_configuration"))
      return false
    end
    self.settings = updated
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

  private :assign_configuration

  def encryptor
    key = Rails.application.key_generator.generate_key("glowbook-integration-settings-v1", 32)
    ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
  end

  def validate_configuration
    values = settings
    required = case provider
    when "smtp" then %w[address port from tls_mode]
    when "duitku" then %w[merchant_code api_key environment expiry_minutes]
    else %w[client_id client_secret]
    end
    required.each { |field| errors.add(:base, I18n.t("integrations.missing_field", field: I18n.t("integrations.fields.#{field}"))) if values[field].blank? }
    if provider == "duitku"
      valid = %w[sandbox production].include?(values["environment"]) && values["merchant_code"].to_s.match?(/\A[a-zA-Z0-9_-]{1,50}\z/) &&
        values["expiry_minutes"].to_s.match?(/\A\d+\z/) && (1..1440).cover?(values["expiry_minutes"].to_i)
      errors.add(:base, I18n.t("duitku.invalid_configuration")) unless valid
      if values["environment"] == "production"
        uri = URI(Rails.configuration.x.app_host)
        errors.add(:base, I18n.t("duitku.https_required")) unless uri.scheme == "https" && uri.host.present? && !%w[localhost 127.0.0.1 ::1].include?(uri.host)
      end
    end
    return unless provider == "smtp"

    errors.add(:base, I18n.t("integrations.invalid_smtp")) unless values["port"].to_s.match?(/\A\d+\z/) && (1..65535).cover?(values["port"].to_i) &&
      values["address"].to_s.match?(/\A[a-zA-Z0-9.\-:]+\z/) && values["from"].to_s.match?(Devise.email_regexp) && %w[starttls tls].include?(values["tls_mode"])
    if values["username"].present? != values["password"].present?
      errors.add(:base, I18n.t("integrations.smtp_credentials_pair"))
    end
  end
end

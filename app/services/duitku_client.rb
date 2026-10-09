require "net/http"
require "json"
require "openssl"

class DuitkuClient
  ENDPOINTS = {
    "sandbox" => { invoice: "https://api-sandbox.duitku.com/api/merchant/createInvoice", status: "https://sandbox.duitku.com/webapi/api/merchant/transactionStatus", checkout_host: "app-sandbox.duitku.com" },
    "production" => { invoice: "https://api-prod.duitku.com/api/merchant/createInvoice", status: "https://passport.duitku.com/webapi/api/merchant/transactionStatus", checkout_host: "app-prod.duitku.com" }
  }.freeze

  class Error < StandardError; end
  class AmbiguousError < Error; end

  attr_reader :merchant_code, :environment

  def self.enabled?
    IntegrationSetting.effective("duitku").ready?
  end

  def self.checkout_label
    key = IntegrationSetting.effective("duitku").settings["environment"] == "sandbox" ? "duitku.checkout_sandbox" : "duitku.checkout"
    I18n.t(key)
  end

  def initialize(configuration: IntegrationSetting.effective("duitku"), allow_disabled: false)
    configuration.enabled = true if allow_disabled
    raise Error, I18n.t("duitku.not_configured") unless configuration.ready?

    values = configuration.settings
    @merchant_code = values.fetch("merchant_code")
    @api_key = values.fetch("api_key")
    @environment = values.fetch("environment")
    @expiry_minutes = values.fetch("expiry_minutes").to_i
    @endpoints = ENDPOINTS.fetch(environment)
    @identity = values.slice("merchant_code", "api_key", "environment")
  end

  def current_configuration?
    current = IntegrationSetting.effective("duitku")
    current.ready? && current.settings.slice("merchant_code", "api_key", "environment") == @identity
  end

  def create_invoice(attempt)
    timestamp = (Time.current.to_f * 1000).to_i.to_s
    response = request(@endpoints.fetch(:invoice), invoice_payload(attempt),
      "x-duitku-merchantcode" => merchant_code, "x-duitku-timestamp" => timestamp,
      "x-duitku-signature" => signature(merchant_code + timestamp))
    raise AmbiguousError, I18n.t("duitku.invoice_unknown") unless response["statusCode"] == "00"
    reference = response.fetch("reference")
    url = response.fetch("paymentUrl")
    raise AmbiguousError, I18n.t("duitku.invalid_checkout") unless reference.is_a?(String) && reference.present? && valid_checkout_url?(url)
    if response["merchantCode"].present? && response["merchantCode"] != merchant_code
      raise AmbiguousError, I18n.t("duitku.invoice_unknown")
    end

    attempt.update!(transaction_id: reference, redirect_url: url, provider_status: "01")
    attempt
  rescue KeyError, URI::InvalidURIError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    raise AmbiguousError, I18n.t("duitku.invoice_unknown")
  end

  def valid_checkout_url?(url)
    return false unless url.is_a?(String)

    uri = URI.parse(url)
    uri.scheme == "https" && uri.host == @endpoints.fetch(:checkout_host) && uri.port == 443 && uri.userinfo.nil?
  rescue URI::InvalidURIError
    false
  end

  def transaction_status(order_id)
    request(@endpoints.fetch(:status), { merchantCode: merchant_code, merchantOrderId: order_id,
      signature: signature(merchant_code + order_id) })
  end

  def valid_signature?(payload)
    expected = signature(payload.fetch("merchantCode").to_s + payload.fetch("amount").to_s + payload.fetch("merchantOrderId").to_s)
    received = payload.fetch("signature").to_s
    received.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(expected, received)
  end

  private

  def signature(value)
    OpenSSL::HMAC.hexdigest("SHA256", @api_key, value)
  end

  def invoice_payload(attempt)
    booking = attempt.booking
    base = Rails.configuration.x.app_host.chomp("/")
    { paymentAmount: attempt.amount, merchantOrderId: attempt.order_id,
      productDetails: "GlowBook #{booking.reference}", customerVaName: booking.user.full_name.to_s.first(20),
      email: booking.user.email, phoneNumber: booking.user.phone.to_s,
      itemDetails: [{ name: "Booking #{booking.reference}", price: attempt.amount, quantity: 1 }],
      callbackUrl: "#{base}#{Rails.application.routes.url_helpers.duitku_callback_path}",
      returnUrl: "#{base}#{Rails.application.routes.url_helpers.booking_path(booking.reference)}", expiryPeriod: @expiry_minutes }
  end

  def request(endpoint, body, headers = {})
    uri = URI(endpoint)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    headers.each { |name, value| request[name] = value }
    request.body = JSON.generate(body)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5, write_timeout: 5) { |http| http.request(request) }
    raise AmbiguousError, I18n.t("duitku.gateway_unavailable") unless response.is_a?(Net::HTTPSuccess)

    parsed = JSON.parse(response.body)
    raise AmbiguousError, I18n.t("duitku.gateway_unavailable") unless parsed.is_a?(Hash)

    parsed
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError
    raise AmbiguousError, I18n.t("duitku.gateway_unavailable")
  end
end

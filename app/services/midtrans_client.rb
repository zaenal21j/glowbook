require "net/http"
require "json"
require "base64"

class MidtransClient
  SNAP_URI = URI("https://app.sandbox.midtrans.com/snap/v1/transactions")
  STATUS_BASE_URI = URI("https://api.sandbox.midtrans.com/v2/")
  SNAP_HOST = "app.sandbox.midtrans.com"

  class Error < StandardError; end
  class AmbiguousError < Error; end

  def initialize(server_key: Rails.configuration.x.midtrans_server_key)
    @server_key = server_key
    raise Error, "Kunci Midtrans sandbox belum dikonfigurasi." if @server_key.blank?
  end

  def create_snap_transaction(payment_attempt)
    response = request(SNAP_URI, Net::HTTP::Post, snap_payload(payment_attempt))
    token = response.fetch("token")
    redirect_url = response.fetch("redirect_url")
    uri = URI.parse(redirect_url)
    raise Error, "URL checkout Midtrans tidak valid." unless uri.scheme == "https" && uri.host == SNAP_HOST

    payment_attempt.update!(snap_token: token, redirect_url: redirect_url, provider_status: nil)
    payment_attempt
  rescue KeyError, URI::InvalidURIError, ActiveRecord::RecordInvalid => e
    raise AmbiguousError, "Midtrans mungkin sudah membuat checkout; buat ulang token dengan order ID yang sama. (#{e.class.name.demodulize})"
  end

  def transaction_status(order_id)
    uri = URI.join(STATUS_BASE_URI.to_s, "#{URI.encode_www_form_component(order_id)}/status")
    request(uri, Net::HTTP::Get)
  end

  private

  def snap_payload(attempt)
    booking = attempt.booking
    services = booking.booking_items.includes(:service).map do |item|
      { id: "service-#{item.service_id}", price: item.price, quantity: 1, name: item.service.name.to_s.first(50) }
    end

    {
      transaction_details: { order_id: attempt.order_id, gross_amount: attempt.amount },
      item_details: services,
      customer_details: { first_name: booking.user.full_name.to_s.first(50), email: booking.user.email },
      callbacks: {
        finish: Rails.application.routes.url_helpers.booking_url(
          booking.reference,
          host: URI(Rails.configuration.x.app_host).host,
          protocol: URI(Rails.configuration.x.app_host).scheme,
          port: URI(Rails.configuration.x.app_host).port
        )
      }
    }
  end

  def request(uri, method, body = nil)
    http_request = method.new(uri)
    http_request["Accept"] = "application/json"
    http_request["Content-Type"] = "application/json"
    http_request["Authorization"] = "Basic #{Base64.strict_encode64("#{@server_key}:")}"
    http_request.body = JSON.generate(body) if body

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5, write_timeout: 5) do |http|
      http.request(http_request)
    end
    parsed = JSON.parse(response.body)
    return parsed if response.is_a?(Net::HTTPSuccess)

    raise AmbiguousError, "Midtrans belum memastikan hasil permintaan (HTTP #{response.code})." if response.server_error?

    raise Error, "Midtrans menolak permintaan (HTTP #{response.code})."
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError, IOError, SystemCallError => e
    raise AmbiguousError, "Midtrans belum memastikan hasil permintaan: #{e.class.name.demodulize}."
  end
end

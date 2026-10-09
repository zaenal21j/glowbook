class PaymentAttemptCsv
  def initialize(scope)
    @scope = scope
  end

  def render
    rows = [ I18n.t("exports.payment_headers") + [I18n.t("duitku.gateway"), I18n.t("duitku.mode")] ]
    @scope.each do |payment|
      booking = payment.booking
      rows << [
        payment.order_id,
        booking.reference,
        booking.start_time&.in_time_zone&.strftime("%Y-%m-%d %H:%M"),
        booking.business.name,
        booking.user.full_name,
        payment.amount,
        payment.payment_type&.humanize,
        payment.status,
        payment.provider_status,
        payment.transaction_id,
        payment.settled_at&.in_time_zone&.iso8601,
        payment.created_at&.in_time_zone&.iso8601,
        payment.provider,
        payment.gateway_environment
      ].map { |value| spreadsheet_safe(value) }
    end

    "\uFEFF#{rows.map { |row| row.map { |value| csv_cell(value) }.join(",") }.join("\r\n")}\r\n"
  end

  private

  def spreadsheet_safe(value)
    text = value.to_s
    text = "'#{text}" if text.match?(/\A[[:space:][:cntrl:]]*[=+\-@]/)
    text
  end

  def csv_cell(value)
    %Q("#{spreadsheet_safe(value).gsub('"', '""')}")
  end
end

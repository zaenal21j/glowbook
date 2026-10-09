class BookingMailer < ApplicationMailer
  def confirmation
    deliver_booking_message(:confirmation)
  end

  def cancellation
    deliver_booking_message(:cancellation)
  end

  def reschedule
    deliver_booking_message(:reschedule)
  end

  private

  def deliver_booking_message(event)
    @booking = params.fetch(:booking)
    @recipient = params.fetch(:recipient)
    locale = params.fetch(:locale, I18n.default_locale).to_sym
    I18n.with_locale(locale) do
      subject = I18n.t("booking_email.#{event}_title")
      mail(to: @recipient, subject: "#{subject} — #{@booking.reference} | GlowBook")
    end
  end
end

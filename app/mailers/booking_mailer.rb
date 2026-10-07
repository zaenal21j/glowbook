class BookingMailer < ApplicationMailer
  def confirmation
    deliver_booking_message("Booking berhasil dikonfirmasi")
  end

  def cancellation
    deliver_booking_message("Booking dibatalkan")
  end

  def reschedule
    deliver_booking_message("Jadwal booking berubah")
  end

  private

  def deliver_booking_message(subject)
    @booking = params.fetch(:booking)
    @recipient = params.fetch(:recipient)
    mail(to: @recipient, subject: "#{subject} — #{@booking.reference} | GlowBook")
  end
end

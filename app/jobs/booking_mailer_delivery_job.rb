require "net/smtp"

class BookingMailerDeliveryJob < ActionMailer::MailDeliveryJob
  queue_as :mailers

  retry_on Net::SMTPServerBusy, Net::OpenTimeout, Net::ReadTimeout,
    wait: :polynomially_longer,
    attempts: 5
end

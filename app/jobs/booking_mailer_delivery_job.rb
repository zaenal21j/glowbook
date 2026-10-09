require "net/smtp"

class BookingMailerDeliveryJob < ActionMailer::MailDeliveryJob
  # Reset tokens are positional mailer arguments and must never reach logs.
  self.log_arguments = false
  queue_as :mailers

  retry_on Net::SMTPServerBusy, Net::OpenTimeout, Net::ReadTimeout,
    wait: :polynomially_longer,
    attempts: 5
end

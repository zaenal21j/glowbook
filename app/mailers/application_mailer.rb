class ApplicationMailer < ActionMailer::Base
  self.delivery_job = BookingMailerDeliveryJob

  default from: ENV.fetch("MAILER_FROM", "no-reply@glowbook.id")
  layout "mailer"
end

class ApplicationMailer < ActionMailer::Base
  self.delivery_job = BookingMailerDeliveryJob

  default from: ENV.fetch("MAILER_FROM", "no-reply@glowbook.id")
  layout "mailer"

  before_deliver :apply_integration_smtp

  private

  def apply_integration_smtp
    configuration = IntegrationSetting.find_by(provider: "smtp")
    return unless configuration

    message.perform_deliveries = configuration.ready?
    return unless message.perform_deliveries

    message.delivery_method(:smtp, configuration.smtp_options)
    message.from = configuration.settings.fetch("from")
  end
end

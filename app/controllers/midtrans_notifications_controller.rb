class MidtransNotificationsController < ApplicationController
  skip_forgery_protection

  def create
    payload = JSON.parse(request.raw_post)
    return head :unprocessable_entity unless payload.is_a?(Hash)

    ProcessMidtransNotification.new(payload: payload).call
    head :ok
  rescue JSON::ParserError, ProcessMidtransNotification::InvalidNotification
    head :unprocessable_entity
  rescue MidtransClient::Error
    head :service_unavailable
  end
end

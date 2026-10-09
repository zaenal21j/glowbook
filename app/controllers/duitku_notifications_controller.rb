class DuitkuNotificationsController < ApplicationController
  skip_forgery_protection only: :create

  def create
    payload = request.request_parameters.slice("merchantCode", "amount", "merchantOrderId", "reference", "signature")
    ProcessDuitkuNotification.new(payload: payload).call
    head :ok
  rescue ProcessDuitkuNotification::InvalidNotification
    head :unprocessable_content
  rescue DuitkuClient::Error
    head :service_unavailable
  end
end

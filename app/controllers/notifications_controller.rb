class NotificationsController < ApplicationController
  include Paginatable

  before_action :authenticate_user!

  def index
    @unread_count = current_user.user_notifications.unread.count
    @notifications = paginate(current_user.user_notifications.recent)
  end

  def mark_read
    notification = current_user.user_notifications.find(params[:id])
    notification.update!(read_at: Time.current) if notification.unread?

    if notification.booking_reference.present?
      redirect_to booking_path(notification.booking_reference)
    else
      redirect_to notifications_path
    end
  end

  def mark_all_read
    current_user.user_notifications.unread.update_all(read_at: Time.current, updated_at: Time.current)
    redirect_to notifications_path, notice: I18n.t("notifications.all_read")
  end
end

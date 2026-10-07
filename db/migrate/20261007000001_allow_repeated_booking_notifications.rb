class AllowRepeatedBookingNotifications < ActiveRecord::Migration[8.1]
  def change
    remove_index :user_notifications, name: "idx_user_notifications_delivery_key"
  end
end

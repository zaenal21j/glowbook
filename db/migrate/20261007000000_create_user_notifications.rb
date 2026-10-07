class CreateUserNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :user_notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :booking_reference, null: false
      t.string :event, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :user_notifications, [ :user_id, :event, :booking_reference ],
              unique: true, name: "idx_user_notifications_delivery_key"
    add_index :user_notifications, [ :user_id, :created_at ]
    add_index :user_notifications, [ :user_id, :read_at ]
  end
end

class CreatePaymentAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_attempts do |t|
      t.references :booking, null: false, foreign_key: true
      t.string :order_id, null: false
      t.bigint :amount, null: false
      t.string :status, null: false, default: "pending"
      t.string :provider_status
      t.string :snap_token
      t.string :redirect_url
      t.string :transaction_id
      t.string :payment_type
      t.datetime :settled_at
      t.timestamps
    end

    add_index :payment_attempts, :order_id, unique: true
    add_index :payment_attempts, :transaction_id, unique: true, where: "transaction_id IS NOT NULL"
    add_index :payment_attempts, :booking_id, unique: true, where: "status = 'pending'", name: "one_pending_payment_attempt_per_booking"
    add_check_constraint :payment_attempts, "amount >= 0", name: "payment_attempts_amount_nonnegative"
    add_check_constraint :payment_attempts,
                         "status IN ('pending', 'settlement', 'capture', 'expire', 'cancel', 'deny', 'failure', 'refund')",
                         name: "payment_attempts_status_valid"
  end
end

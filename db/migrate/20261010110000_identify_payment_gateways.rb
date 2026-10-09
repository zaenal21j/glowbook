class IdentifyPaymentGateways < ActiveRecord::Migration[8.1]
  def change
    add_column :payment_attempts, :provider, :string, null: false, default: "midtrans"
    change_column_default :payment_attempts, :provider, from: "midtrans", to: "duitku"
    add_column :payment_attempts, :gateway_environment, :string
    add_column :payment_attempts, :merchant_code, :string
    add_column :payment_attempts, :status_checked_at, :datetime
    add_check_constraint :payment_attempts, "provider IN ('midtrans', 'duitku')", name: "payment_attempts_provider_valid"
  end
end

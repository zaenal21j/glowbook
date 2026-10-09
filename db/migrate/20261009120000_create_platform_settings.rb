class CreatePlatformSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_settings do |t|
      t.boolean :business_registration_open, null: false, default: true
      t.decimal :commission_percentage, precision: 5, scale: 2, null: false, default: 5.0

      t.timestamps
    end
  end
end

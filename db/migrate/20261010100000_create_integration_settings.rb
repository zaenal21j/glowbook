class CreateIntegrationSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :integration_settings do |t|
      t.string :provider, null: false
      t.boolean :enabled, null: false, default: false
      t.text :encrypted_settings
      t.timestamps
    end
    add_index :integration_settings, :provider, unique: true
  end
end

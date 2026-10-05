class CreateStaffServices < ActiveRecord::Migration[8.1]
  def change
    create_table :staff_services do |t|
      t.references :staff, null: false, foreign_key: { to_table: :staffs }
      t.references :service, null: false, foreign_key: true

      t.timestamps
    end
    add_index :staff_services, [:staff_id, :service_id], unique: true
  end
end

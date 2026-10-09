class AddBioToStaffs < ActiveRecord::Migration[8.1]
  def change
    add_column :staffs, :bio, :text
  end
end

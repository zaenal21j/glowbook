class StaffService < ApplicationRecord
  belongs_to :staff
  belongs_to :service

  validates :staff, presence: true
  validates :service, presence: true
  validates :service_id, uniqueness: { scope: :staff_id }
end

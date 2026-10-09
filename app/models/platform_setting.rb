class PlatformSetting < ApplicationRecord
  validates :business_registration_open, inclusion: { in: [ true, false ] }
  validates :commission_percentage,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  def self.current
    find_by(id: 1) || create!(id: 1)
  rescue ActiveRecord::RecordNotUnique
    find(1)
  end
end

# Initial production setup. Adds reference data and the first administrator;
# existing records and passwords are preserved when the task is repeated.
class PlatformBootstrap
  CITIES = %w[Jakarta Bandung Surabaya Bali Yogyakarta Medan].freeze
  CATEGORIES = [
    ["Rambut", "rambut", "scissors"], ["Facial", "facial", "sparkles"],
    ["Nail Art", "nail-art", "hand"], ["Massage", "massage", "lotus"],
    ["Hair Coloring", "hair-coloring", "palette"], ["Eyelash", "eyelash", "eye"],
    ["Spa", "spa", "flower"], ["Barber", "barber", "razor"],
    ["Makeup", "makeup", "brush"], ["Body Treatment", "body-treatment", "droplet"]
  ].freeze

  def self.call(email:, password: nil, name: "Admin GlowBook")
    email = email.to_s.strip.downcase
    raise ArgumentError, "ADMIN_EMAIL is required" if email.blank?

    ApplicationRecord.transaction do
      admin = User.find_or_initialize_by(email: email)
      if admin.persisted?
        raise ArgumentError, "The existing account is not an administrator" unless admin.admin?
      else
        raise ArgumentError, "ADMIN_PASSWORD must contain at least 12 characters" if password.to_s.length < 12

        admin.assign_attributes(name: name, role: :admin, password: password, password_confirmation: password)
        admin.save!
      end

      CITIES.each { |city| City.find_or_create_by!(slug: city.parameterize) { |record| record.name = city } }
      CATEGORIES.each_with_index do |(label, slug, icon), index|
        Category.find_or_create_by!(slug: slug) do |record|
          record.assign_attributes(name: label, icon_name: icon, position: index, is_popular: index < 8)
        end
      end
      PlatformSetting.current
      admin
    end
  end
end

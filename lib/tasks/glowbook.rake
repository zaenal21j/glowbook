namespace :glowbook do
  desc "Prepare initial reference data and an administrator without demo data"
  task bootstrap: :environment do
    PlatformBootstrap.call(email: ENV["ADMIN_EMAIL"], password: ENV["ADMIN_PASSWORD"],
                           name: ENV.fetch("ADMIN_NAME", "Admin GlowBook"))
    puts "GlowBook bootstrap complete. Existing data and administrator passwords were preserved."
  end
end

# GlowBook demo data - realistic fictional Indonesian beauty & wellness marketplace.
# Idempotent: wipes domain tables first, then recreates everything.

puts "== Seeding GlowBook =="

# --- Clean slate -----------------------------------------------------------
[BookingItem, Booking, Review, Favorite, Promotion, BlockedTime, StaffBreak,
 StaffSchedule, StaffService, Staff, Service, BusinessHour, BusinessGallery,
 BusinessCategory, Business, Category, City, User].each(&:delete_all)
ActiveStorage::Attachment.where(record_type: ["Business", "Staff", "BusinessGallery", "Service"]).delete_all
ActiveStorage::Blob.delete_all

def fetch_image(seed, w = 1200, h = 800)
  io = URI.open("https://picsum.photos/seed/#{seed}/#{w}/#{h}", read_timeout: 20)
  { io: io, filename: "#{seed}.jpg", content_type: "image/jpeg" }
rescue StandardError => e
  Rails.logger.warn("picsum seed #{seed} failed: #{e.message}")
  nil
end

def attach(record, attachment_name, seed, w = 1200, h = 800)
  return unless record.respond_to?(attachment_name)

  blob = fetch_image(seed, w, h)
  record.send(attachment_name).attach(blob) if blob
rescue StandardError => e
  Rails.logger.warn("attach #{seed} failed: #{e.message}")
end

# --- Cities -----------------------------------------------------------------
city_data = {
  "Jakarta"    => "jakarta",
  "Bandung"    => "bandung",
  "Surabaya"   => "surabaya",
  "Bali"       => "bali",
  "Yogyakarta" => "yogyakarta",
  "Medan"      => "medan"
}
cities = city_data.map { |name, slug| City.create!(name: name, slug: slug) }
city_by = cities.index_by(&:name)

# --- Categories (icons from the design system) ------------------------------
categories = [
  { name: "Rambut",   slug: "rambut",   icon: "scissors", popular: true,  tagline: "Potong & styling" },
  { name: "Facial",   slug: "facial",   icon: "sparkles", popular: true,  tagline: "Perawatan wajah" },
  { name: "Nail Art", slug: "nail-art", icon: "hand",     popular: true,  tagline: "Manicure & pedicure" },
  { name: "Massage",  slug: "massage",  icon: "lotus",    popular: true,  tagline: "Relaksasi tubuh" },
  { name: "Hair Coloring", slug: "hair-coloring", icon: "palette", popular: true,  tagline: "Pewarnaan rambut" },
  { name: "Eyelash",  slug: "eyelash",  icon: "eye",      popular: true,  tagline: "Extension bulu mata" },
  { name: "Spa",      slug: "spa",      icon: "flower",   popular: true,  tagline: "Spa & wellness" },
  { name: "Barber",   slug: "barber",   icon: "razor",    popular: true,  tagline: "Potong pria" },
  { name: "Makeup",   slug: "makeup",   icon: "brush",    popular: false, tagline: "Tata rias" },
  { name: "Body Treatment", slug: "body-treatment", icon: "droplet", popular: false, tagline: "Perawatan tubuh" }
]
cat_by_slug = {}
categories.each_with_index do |c, i|
  cat_by_slug[c[:slug]] = Category.create!(
    name: c[:name], slug: c[:slug], icon_name: c[:icon],
    tagline: c[:tagline], is_popular: c[:popular], position: i
  )
end

# --- Users -------------------------------------------------------------------
def seed_user(name, email, role, phone: nil, password: "password123")
  User.create!(
    name: name, email: email, role: role, phone: phone,
    password: password, password_confirmation: password
  )
end

admin        = seed_user("Admin GlowBook", "admin@glowbook.id", :admin)
customer1    = seed_user("Sari Dewi",     "sari@example.com",    :customer, phone: "+628111000001")
customer2    = seed_user("Rina Putri",    "rina@example.com",    :customer, phone: "+628111000002")
customer3    = seed_user("Budi Santoso",  "budi@example.com",    :customer, phone: "+628111000003")
customers = [customer1, customer2, customer3]
15.times do |i|
  customers << seed_user("Pelanggan #{i + 4}", "pelanggan#{i + 4}@example.com", :customer)
end

# --- Businesses ---------------------------------------------------------------
FIRST_NAMES  = %w[Rina Sari Dewi Ayu Putri Maya Intan Lina Wulan Ratna Dina Farah Gita Hana Ika Jihan Kartika Melati Nadia Oki
                  Andi Bima Candra Dedi Eko Fajar Gilang Hendra Iqbal Joko Krisna Lukman Mira Nanda Oski Panji Rio Satria Tono Umar Vino]
STAFF_TITLES = ["Senior Therapist", "Beauty Specialist", "Hair Stylist", "Nail Artist", "Massage Therapist", "Skin Expert", "Barber", "Colorist"]
AVATAR_COLORS = %w[rose pink fuchsia purple violet indigo sky teal emerald amber orange]

BUSINESS_TEMPLATE = [
  # name prefix, categories, city, services (name, dur, price), rating
  ["Bellezza Hair Studio", %w[rambut facial eyelash], "Jakarta", 4.8,
   [["Haircut Premium", 60, 150_000], ["Facial Premium", 90, 400_000], ["Hair Coloring", 120, 750_000],
    ["Eyelash Extension", 60, 300_000], ["Blow Dry & Styling", 45, 120_000]]],
  ["Glow Spa & Wellness", %w[spa massage facial], "Jakarta", 4.9,
   [["Balinese Massage", 90, 250_000], ["Aromatherapy Spa", 120, 450_000], ["Facial Glow", 60, 300_000],
    ["Body Scrub", 60, 200_000]]],
  ["Nailuxe Studio", %w[nail-art makeup], "Jakarta", 4.7,
   [["Manicure Classic", 45, 120_000], ["Pedicure Spa", 60, 150_000], ["Gel Nail Art", 90, 250_000],
    ["Makeup Party", 90, 500_000]]],
  ["The Gentleman's Cut", %w[barber rambut], "Jakarta", 4.6,
   [["Haircut Pria", 45, 100_000], ["Beard Trim", 30, 60_000], ["Haircut + Beard", 60, 140_000],
    ["Hair Spa Pria", 60, 180_000]]],
  ["Lumiere Beauty Clinic", %w[facial body-treatment], "Jakarta", 4.7,
   [["Acne Treatment", 60, 350_000], ["Anti Aging Facial", 90, 500_000], ["Whitening Body Treatment", 120, 650_000]]],
  ["Natura Beauty House", %w[facial spa massage], "Jakarta", 4.6,
   [["Organic Facial", 60, 250_000], ["Relaxation Massage", 90, 220_000], ["Detox Spa Package", 120, 480_000]]],
  ["Bandung Beauty Loft", %w[rambut makeup nail-art], "Bandung", 4.8,
   [["Haircut & Styling", 60, 130_000], ["Hair Smoothing", 120, 600_000], ["Makeup Wisuda", 90, 450_000], ["Manicure Modern", 45, 100_000]]],
  ["Parahyangan Spa Retreat", %w[spa massage body-treatment], "Bandung", 4.9,
   [["Hot Stone Massage", 90, 300_000], ["Milk Bath Spa", 120, 420_000], ["Foot Reflexology", 60, 150_000]]],
  ["Dago Barber Club", %w[barber], "Bandung", 4.5,
   [["Potong Rambut Pria", 45, 80_000], ["Cukur Jenggot", 30, 50_000], ["Hair Tonic Massage", 30, 70_000]]],
  ["Surabaya Glow Studio", %w[facial rambut eyelash], "Surabaya", 4.6,
   [["Facial Brightening", 60, 280_000], ["Keratin Treatment", 120, 700_000], ["Eyelash Volume", 60, 320_000]]],
  ["Bali Serenity Spa", %w[spa massage body-treatment], "Bali", 5.0,
   [["Traditional Balinese Massage", 90, 200_000], ["Flower Bath Ritual", 120, 380_000], ["Four Hands Massage", 60, 350_000]]],
  ["Ubud Beauty Sanctuary", %w[facial makeup nail-art], "Bali", 4.8,
   [["Tropical Facial", 60, 260_000], ["Bridal Makeup", 150, 900_000], ["Beach Nail Art", 60, 180_000]]],
  ["Malioboro Beauty Corner", %w[rambut facial nail-art], "Yogyakarta", 4.5,
   [["Haircut Wanita", 60, 90_000], ["Facial Basic", 60, 150_000], ["Nail Art Jawa", 60, 130_000]]],
  ["Prambanan Spa Village", %w[spa massage], "Yogyakarta", 4.7,
   [["Javanese Massage", 90, 180_000], ["Herbal Body Scrub", 60, 160_000]]],
  ["Medan Beauty Palace", %w[rambut facial makeup], "Medan", 4.4,
   [["Hair Coloring Ekspres", 90, 400_000], ["Facial Durian Glow", 60, 200_000], ["Makeup Acara", 90, 380_000]]],
  ["Kesawan Barber Shop", %w[barber], "Medan", 4.3,
   [["Potong Klasik", 45, 60_000], ["Face Cleaning", 30, 40_000]]]
].freeze

STREET_POOL = {
  "Jakarta"    => ["Jl. Kemang Raya No. 88", "Jl. Senopati No. 21", "Jl. Cikajang No. 44", "Jl. Wolter Monginsidi No. 12", "Jl. Gunawarman No. 9"],
  "Bandung"    => ["Jl. Riau No. 27", "Jl. Dago No. 55", "Jl. Sumur Bandung No. 3", "Jl. Progo No. 14"],
  "Surabaya"   => ["Jl. Darmo No. 72", "Jl. Mayjend Sungkono No. 18", "Jl. Raya Gubeng No. 34"],
  "Bali"       => ["Jl. Raya Seminyak No. 8", "Jl. Monkey Forest No. 15", "Jl. Sunset Road No. 90"],
  "Yogyakarta" => ["Jl. Malioboro No. 60", "Jl. Kaliurang KM 5.2", "Jl. Prawirotaman No. 23"],
  "Medan"      => ["Jl. Kesawan No. 41", "Jl. Gatot Subroto No. 77", "Jl. Asia No. 5"]
}.freeze

CITY_COORD = {
  "Jakarta"    => [-6.24, 106.82], "Bandung" => [-6.91, 107.61], "Surabaya" => [-7.26, 112.75],
  "Bali"       => [-8.65, 115.22], "Yogyakarta" => [-7.79, 110.37], "Medan" => [3.59, 98.67]
}.freeze

 businesses_index = 0
 created_businesses = []

BUSINESS_TEMPLATE.each_with_index do |(name, cat_slugs, city_name, rating, services), bi|
  owner = seed_user(
    "Owner #{name}", "owner#{bi + 1}@glowbook.id", :business_owner,
    phone: "+62812#{format('%07d', bi * 111 + 1000)}"
  )
  city = city_by[city_name]
  slug = name.parameterize
  streets = STREET_POOL[city_name]
  lat, lng = CITY_COORD[city_name]
  lat = lat + (bi % 5 - 2) * 0.008
  lng = lng + (bi % 3 - 1) * 0.008

  business = Business.create!(
    name: name,
    slug: slug,
    description: "#{name} adalah tempat perawatan kecantikan & wellness premium di #{city_name}. " \
                 "Kami mengutamakan produk berkualitas tinggi, terapis bersertifikat, dan pengalaman yang menyenangkan " \
                 "agar setiap pelanggan merasa lebih percaya diri setelah berkunjung.",
    address: "#{streets[bi % streets.length]}, #{city_name}",
    phone: "+6221#{format('%08d', 50_000_000 + bi * 137)}",
    owner: owner,
    city: city,
    latitude: lat,
    longitude: lng,
    avg_rating: rating,
    status: :active
  )

  cat_slugs.each { |cs| BusinessCategory.create!(business: business, category: cat_by_slug[cs]) }

  # Business hours: Mon-Sat 09:00-21:00, Sunday closed (some open)
  (0..6).each do |wd|
    if wd == 0
      BusinessHour.create!(business: business, weekday: wd, open_minute: 540, close_minute: 1260, closed: (bi % 3 != 0))
    else
      BusinessHour.create!(business: business, weekday: wd, open_minute: 540, close_minute: 1260, closed: false)
    end
  end

  # Services + staff
  staff_count = [2 + (bi % 3), services.size].min
  staff_members = staff_count.times.map do |si|
    Staff.create!(
      business: business,
      name: "#{FIRST_NAMES[(bi * 7 + si) % FIRST_NAMES.size]} #{%w[Sari Dewi Lestari][si % 3]}",
      title: STAFF_TITLES[(bi + si) % STAFF_TITLES.size],
      avatar_color: AVATAR_COLORS[(bi + si) % AVATAR_COLORS.size],
      active: true
    )
  end

  services.each_with_index do |(sname, dur, price), si|
    service = Service.create!(
      business: business,
      category: cat_by_slug[cat_slugs[si % cat_slugs.length]],
      name: sname,
      description: "#{sname} oleh terapis profesional dengan produk premium di #{name}.",
      duration_minutes: dur,
      price: price,
      position: si,
      active: true
    )
    staff_members.each_with_index do |sm, smi|
      StaffService.create!(staff: sm, service: service) if smi.zero? || rand < 0.85
    end
  end

  # Staff schedules: staggered shifts 09:00-17:00 / 11:00-19:00 / 13:00-21:00
  staff_members.each_with_index do |sm, si|
    start_m = [540, 660, 780][si % 3]
    (1..6).each do |wd| # Mon..Sat
      StaffSchedule.create!(staff: sm, weekday: wd, start_minute: start_m, end_minute: start_m + 480)
    end
    # lunch break 12:00-13:00 Mon..Sat
    StaffBreak.create!(staff: sm, weekday: 1, start_minute: 720, end_minute: 780)
    StaffBreak.create!(staff: sm, weekday: rand(2..6), start_minute: 720, end_minute: 780)
  end

  # Gallery images
  4.times do |gi|
    g = BusinessGallery.create!(business: business, caption: "Galeri #{gi + 1}", position: gi)
    attach(g, :image, "#{slug}-gallery-#{gi}", 1200, 800)
  end

  attach(business, :cover_image, "#{slug}-cover", 1600, 900)
  attach(business, :logo_image, "#{slug}-logo", 400, 400)

  # Reviews
  review_texts = [
    "Pelayanan sangat bagus, hasilnya memuaskan!",
    "Terapisnya ramah dan profesional. Tempatnya juga bersih.",
    "Sudah langganan di sini, tidak pernah kecewa.",
    "Harga sepadan dengan kualitas. Recommended!",
    "Nyaman, rapi, hasil natural. Pasti balik lagi.",
    "Booking mudah, pelayanan cepat, sangat memuaskan."
  ]
  review_count = 6 + (bi % 4)
  review_count.times do |ri|
    user = customers[ri % customers.size]
    next if Review.exists?(user: user, business: business)

    Review.create!(
      user: user,
      business: business,
      rating: rating >= 4.8 ? [5, 5, 4, 5].sample : [5, 4, 4, 5, 3].sample,
      comment: review_texts[ri % review_texts.size],
      created_at: (bi * 3 + ri).days.ago
    )
  end

  # Promotions for some businesses
  if bi % 3 == 0
    Promotion.create!(
      business: business,
      title: "Diskon #{20 + bi % 3 * 5}%",
      description: "Promo spesial akhir pean untuk semua layanan!",
      discount_percent: 20 + bi % 3 * 5,
      starts_at: 5.days.ago,
      ends_at: 30.days.from_now,
      active: true
    )
  end

  created_businesses << business
  businesses_index = bi
end

# --- Blocked times (demo) -------------------------------------------------
first_biz = created_businesses.first
staff0 = first_biz.staff.first
BlockedTime.create!(
  business: first_biz, staff: staff0,
  reason: "Training internal",
  start_time: 2.days.from_now.change(hour: 13, min: 0),
  end_time: 2.days.from_now.change(hour: 15, min: 0)
)

# --- Bookings ----------------------------------------------------------------
statuses = %i[confirmed completed cancelled]
created_businesses.first(6).each_with_index do |biz, i|
  user = customers[i % customers.size]
  svc = biz.services.first
  staff_member = biz.staff.joins(:staff_services).where(staff_services: { service_id: svc.id }).first || biz.staff.first
  # Explicit month/day so seeded "past" bookings stay stable no matter when seeds run.
  day = [15, 12, 8, 22, 25, 27][i]
  start_time = Time.zone.local(2026, 9, day, 10, 0, 0)
  end_time = start_time + svc.duration_minutes.minutes
  booking = Booking.new(
    user: user,
    business: biz,
    reference: "GB-2026#{format('%02d', 9)}#{format('%02d', day)}-#{format('%06d', i + 1)}",
    start_time: start_time,
    end_time: end_time,
    status: statuses[i % statuses.size],
    total_amount: svc.price,
    payment_method: "pay_at_venue",
    notes: nil
  )
  booking.save!(validate: false) # seeds may represent past bookings; app UI enforces future-only
  BookingItem.create!(
    booking: booking,
    service: svc,
    staff: staff_member,
    price: svc.price,
    duration_minutes: svc.duration_minutes,
    during: (start_time...end_time)
  )
end

puts "== Seeded: #{City.count} cities, #{Category.count} categories, #{User.count} users,"
puts "   #{Business.count} businesses, #{Service.count} services, #{Staff.count} staff,"
puts "   #{Booking.count} bookings, #{Review.count} reviews, #{Promotion.count} promotions =="

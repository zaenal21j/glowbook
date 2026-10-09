FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "Pengguna #{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    role { :customer }

    trait :owner do
      role { :business_owner }
    end
    trait :admin do
      role { :admin }
    end
  end

  factory :city do
    sequence(:name) { |n| "Kota #{n}" }
    sequence(:slug) { |n| "kota-#{n}" }
  end

  factory :category do
    sequence(:name) { |n| "Kategori #{n}" }
    sequence(:slug) { |n| "kategori-#{n}" }
  end

  factory :business do
    sequence(:name) { |n| "Salon #{n}" }
    sequence(:slug) { |n| "salon-#{n}" }
    address { "Jl. Melati No. 1" }
    phone { "+6281234567890" }
    owner factory: %i[user owner]
    city

    transient do
      open_hour { 9 }
      close_hour { 17 }
      closed_sunday { true }
    end

    after :create do |business, evaluator|
      (0..6).each do |wday|
        closed = evaluator.closed_sunday && wday.zero?
        BusinessHour.create!(
          business: business,
          weekday: wday,
          open_minute: evaluator.open_hour * 60,
          close_minute: evaluator.close_hour * 60,
          closed: closed
        )
      end
    end
  end

  factory :service do
    sequence(:name) { |n| "Layanan #{n}" }
    price { 100_000 }
    duration_minutes { 60 }
    business
    category

    trait :short do
      duration_minutes { 30 }
    end
  end

  factory :staff do
    sequence(:name) { |n| "Staff #{n}" }
    title { "Terapis" }
    business

    transient do
      start_hour { 9 }
      end_hour { 17 }
      weekdays { [ 1, 2, 3, 4, 5, 6 ] }
    end

    after :create do |member, evaluator|
      evaluator.weekdays.each do |wday|
        StaffSchedule.create!(
          staff: member,
          weekday: wday,
          start_minute: evaluator.start_hour * 60,
          end_minute: evaluator.end_hour * 60
        )
      end
    end

    trait :sunday_too do
      weekdays { [ 0, 1, 2, 3, 4, 5, 6 ] }
    end
  end

  factory :staff_service do
    staff
    service
  end

  factory :staff_break do
    staff
    weekday { 1 }
    start_minute { 12 * 60 }
    end_minute { 13 * 60 }
  end

  factory :booking do
    association :user, factory: %i[user]
    business
    start_time { 1.day.from_now.change(hour: 10, min: 0) }
    end_time { 1.day.from_now.change(hour: 11, min: 0) }
    total_amount { 100_000 }
    payment_method { "pay_at_venue" }
    status { :confirmed }

    transient do
      with_item { nil }
      with_item_staff { nil }
    end

    trait :past do
      start_time { 2.days.ago.change(hour: 10, min: 0) }
      end_time { 2.days.ago.change(hour: 11, min: 0) }
      status { :completed }
      sequence(:reference) { |n| "GB-PAST-#{n}" }
      to_create { |booking| booking.save!(validate: false) }
    end

    after :create do |booking, evaluator|
      if evaluator.with_item
        BookingItem.create!(
          booking: booking,
          service: evaluator.with_item,
          staff: evaluator.with_item_staff,
          price: evaluator.with_item.price,
          duration_minutes: evaluator.with_item.duration_minutes,
          during: booking.start_time...booking.end_time
        )
      end
    end
  end

  factory :booking_item do
    booking
    service { association :service, business: booking.business }
    staff { nil }
    price { service.price }
    duration_minutes { service.duration_minutes }
    during { booking.start_time...booking.end_time }
  end

  factory :payment_attempt do
    booking
    provider { "duitku" }
    gateway_environment { "production" }
    merchant_code { "DTEST" }
    sequence(:order_id) { |n| "GB-PAYMENT-#{n}" }
    amount { booking.total_amount }
    status { "pending" }
  end

  factory :review do
    association :user, factory: %i[user]
    business
    rating { 5 }
    comment { "Bagus sekali!" }
  end

  factory :promotion do
    title { "Diskon Spesial" }
    discount_percent { 20 }
    business
    active { true }
    starts_at { 1.day.ago }
    ends_at { 1.month.from_now }
  end
end

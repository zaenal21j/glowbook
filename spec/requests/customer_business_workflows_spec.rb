require "rails_helper"

RSpec.describe "Customer and business workflows", type: :request do
  include ActiveJob::TestHelper

  let(:customer) { create(:user) }
  let(:owner) { create(:user, :owner) }
  let(:business) { create(:business, owner: owner) }

  before do
    travel_to Time.zone.local(2026, 10, 12, 8)
    sign_in customer
  end

  it "registers a business, enables owner setup, and publishes only after admin approval" do
    city = create(:city)
    category = create(:category)
    expect {
      post buat_registrasi_bisnis_path, params: { business: { name: "Ayu Beauty", address: "Jl. Melati 1",
        phone: "081234567890", city_id: city.id, category_ids: [category.id], status: "active", owner_id: owner.id } }
    }.to change(Business, :count).by(1)
    registered = customer.businesses.sole
    expect(registered).to be_pending
    expect(registered.categories).to contain_exactly(category)
    expect(registered.business_hours.count).to eq(7)
    expect(customer.reload).to be_business_owner
    expect(response).to redirect_to(dashboard_root_path)
    get dashboard_root_path
    expect(response).to have_http_status(:ok)
    get business_detail_path(registered.slug)
    expect(response).to have_http_status(:not_found)
    sign_in create(:user, :admin)
    patch activate_admin_business_path(registered.id)
    expect(registered.reload).to be_active
    get business_detail_path(registered.slug)
    expect(response).to have_http_status(:ok)
  end

  it "retains an invalid business registration for correction without changing the user's role" do
    category = create(:category)
    post buat_registrasi_bisnis_path, params: { business: { name: "Incomplete", category_ids: [category.id] } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(customer.reload).to be_customer
    expect(customer.businesses).to be_empty
    expect(response.body).to include("Incomplete")
  end

  it "handles favorite buttons submitted through Turbo without a missing template" do
    headers = { "Accept" => "text/vnd.turbo-stream.html" }
    post business_favorite_path(business.slug), headers: headers
    expect(response).to have_http_status(:see_other)
    expect(customer.favorites.where(business: business).count).to eq(1)
    post business_favorite_path(business.slug), headers: headers
    expect(customer.favorites.where(business: business).count).to eq(1)
    delete business_unfavorite_path(business.slug), headers: headers
    expect(response).to have_http_status(:see_other)
    expect(customer.favorites.where(business: business)).to be_empty
  end

  it "submits the actual review form after a completed visit and shows duplicate errors" do
    create(:booking, :past, business: business, user: customer)
    get new_business_review_path(business.slug)
    expect(response).to have_http_status(:ok)
    action = Nokogiri::HTML(response.body).at_css('form[action$="/reviews"]')["action"]
    expect(action).to eq(business_reviews_path(business.slug))
    expect {
      post action, params: { review: { rating: 5, comment: "Excellent service" } }
    }.to change(Review, :count).by(1)
    expect(response).to redirect_to(business_detail_path(business.slug))
    post action, params: { review: { rating: 4, comment: "Duplicate" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include(I18n.t("validation.duplicate_review"))
    expect(customer.reviews.count).to eq(1)
  end

  it "rejects reviews without a completed visit and reviews by the business owner" do
    expect {
      post business_reviews_path(business.slug), params: { review: { rating: 5, comment: "Not visited" } }
    }.not_to change(Review, :count)
    expect(response).to redirect_to(business_detail_path(business.slug))
    create(:booking, :past, business: business, user: owner)
    sign_in owner
    expect {
      post business_reviews_path(business.slug), params: { review: { rating: 5, comment: "My own business" } }
    }.not_to change(Review, :count)
  end

  it "lets customer and owner exchange messages and marks only incoming messages read" do
    post business_chat_path(business.slug)
    conversation = Conversation.find_by!(customer: customer, business: business)
    expect(response).to redirect_to(chat_path(conversation))
    post chat_messages_path(conversation), params: { chat_message: { body: "  Can I book tomorrow?  ", sender_id: owner.id } }
    message = conversation.chat_messages.sole
    expect(message.sender).to eq(customer)
    expect(message.body).to eq("Can I book tomorrow?")
    expect(message.read_at).to be_nil
    sign_in owner
    get dashboard_chats_path
    expect(response).to have_http_status(:ok)
    get chat_path(conversation)
    expect(response).to have_http_status(:ok)
    expect(message.reload.read_at).to be_present
    post chat_messages_path(conversation), params: { chat_message: { body: "Yes, welcome!" } }
    reply = conversation.chat_messages.order(:id).last
    sign_in customer
    get chat_messages_feed_path(conversation), params: { after_id: message.id }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.map { |item| item["body"] }).to eq(["Yes, welcome!"])
    expect(reply.reload.read_at).to be_present
  end

  it "escapes message HTML and rejects empty messages" do
    conversation = Conversation.create!(customer: customer, business: business)
    post chat_messages_path(conversation), params: { chat_message: { body: "<script>alert(1)</script>" } }
    get chat_path(conversation)
    expect(response.body).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
    expect(response.body).not_to include("<script>alert(1)</script>")
    post chat_messages_path(conversation), params: { chat_message: { body: "   " } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(conversation.chat_messages.count).to eq(1)
  end

  it "denies chat access and message creation to outsiders and inactive staff" do
    conversation = Conversation.create!(customer: customer, business: business)
    staff_user = create(:user, role: :staff)
    create(:staff, business: business, user: staff_user, active: false)
    [create(:user), staff_user].each do |user|
      sign_in user
      get chat_path(conversation)
      expect(response).to have_http_status(:not_found)
      sign_in user
      expect {
        post chat_messages_path(conversation), params: { chat_message: { body: "Not allowed" } }
      }.not_to change(ChatMessage, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "uploads a gallery image, displays it publicly, and removes it from the owner's form" do
    sign_in owner
    business
    image = Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png")
    post dashboard_galleries_path, params: { business_gallery: { image: image, caption: "Our salon" } }
    expect(response).to redirect_to(dashboard_galleries_path)
    gallery = business.business_galleries.sole
    expect(gallery.image).to be_attached
    get dashboard_galleries_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Our salon")
    get business_detail_path(business.slug)
    expect(response).to have_http_status(:ok)
    delete dashboard_gallery_path(gallery)
    expect(BusinessGallery.exists?(gallery.id)).to be(false)
  end

  it "rejects a gallery entry without an image and another business's gallery deletion" do
    sign_in owner
    business
    post dashboard_galleries_path, params: { business_gallery: { caption: "No image" } }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(business.business_galleries).to be_empty
    other = create(:business)
    gallery = other.business_galleries.build(caption: "Private photo")
    gallery.image.attach(io: File.open(Rails.root.join("public/icon.png")), filename: "image.png", content_type: "image/png")
    gallery.save!
    delete dashboard_gallery_path(gallery)
    expect(response).to have_http_status(:not_found)
    expect(BusinessGallery.exists?(gallery.id)).to be(true)
  end

  it "delivers confirmation, cancellation, and rescheduling email and in-app notifications" do
    booking = create(:booking, business: business, user: customer)
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    ActionMailer::Base.deliveries.clear
    %i[confirmation cancellation reschedule].each do |event|
      perform_enqueued_jobs do
        I18n.with_locale(:en) { BookingNotificationDelivery.new(booking: booking, event: event).call }
      end
    end
    expect(ActionMailer::Base.deliveries.size).to eq(6)
    expect(ActionMailer::Base.deliveries.flat_map(&:to).uniq.sort).to eq([customer.email, owner.email].sort)
    expect(ActionMailer::Base.deliveries.map(&:subject).join(" ")).to include("Booking confirmed", "Booking cancelled", "Booking rescheduled")
    expect(customer.user_notifications.count).to eq(3)
    expect(owner.user_notifications.count).to eq(3)
    expect(customer.user_notifications.pluck(:body).join(" ")).to include(booking.reference)
  ensure
    ActiveJob::Base.queue_adapter = original_adapter if original_adapter
    ActionMailer::Base.deliveries.clear
  end

  it "scopes notification access and mark-all-read to the signed-in customer" do
    booking = create(:booking, business: business, user: customer)
    BookingNotificationDelivery.new(booking: booking, event: :confirmation).call
    mine = customer.user_notifications.sole
    theirs = owner.user_notifications.sole
    patch read_notification_path(theirs)
    expect(response).to have_http_status(:not_found)
    expect(theirs.reload.read_at).to be_nil
    sign_in customer
    patch mark_all_notifications_read_path
    expect(mine.reload.read_at).to be_present
    expect(theirs.reload.read_at).to be_nil
    patch read_notification_path(mine)
    expect(response).to redirect_to(booking_path(booking.reference))
  end

  it "serves the PWA manifest, cache worker, and offline fallback" do
    get pwa_manifest_path
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("name")).to eq("GlowBook")
    get pwa_service_worker_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("caches.open", "/offline.html")
    expect(File.read(Rails.root.join("public/offline.html"))).to include("Kamu sedang offline")
  end

  it "reloads the document when switching language so offline preferences use the current language" do
    get root_path
    form = Nokogiri::HTML(response.body).at_css("form[action='#{locale_path(:en)}']")
    expect(form["data-turbo"]).to eq("false")
    post form["action"]
    follow_redirect!
    expect(Nokogiri::HTML(response.body).at_css("html")["lang"]).to eq("en")
    expect(response.body).to include("Language changed")
  end
end

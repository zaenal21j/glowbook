class BookingNotificationDelivery
  EVENTS = %i[confirmation cancellation reschedule].freeze

  def initialize(booking:, event:)
    @booking = booking
    @event = event.to_sym
  end

  def call
    raise ArgumentError, "Jenis notifikasi booking tidak valid." unless EVENTS.include?(@event)

    notification_recipients.each do |user|
      create_in_app_notification(user)
    rescue StandardError => e
      Rails.logger.error("Gagal membuat notifikasi booking #{@booking.reference} untuk user #{user.id}: #{e.class}: #{e.message}")
    end

    notification_recipients.map(&:email).compact_blank.uniq.each do |recipient|
      BookingMailer.with(booking: @booking, recipient: recipient).public_send(@event).deliver_later
    rescue StandardError => e
      Rails.logger.error("Gagal mengantrekan email booking #{@booking.reference}: #{e.class}: #{e.message}")
    end
  end

  private

  def notification_recipients
    [ @booking.user, @booking.business.owner ].compact.uniq
  end

  def create_in_app_notification(user)
    title, body = notification_content(user)

    UserNotification.create!(
      user: user,
      booking_reference: @booking.reference,
      event: @event.to_s,
      title: title,
      body: body
    )
  end

  def notification_content(user)
    title = case @event
    when :confirmation
      user == @booking.business.owner ? "Booking baru masuk" : "Booking berhasil dibuat"
    when :cancellation
      "Booking dibatalkan"
    when :reschedule
      "Jadwal booking diubah"
    end

    appointment = @booking.start_time.in_time_zone.strftime("%d-%m-%Y pukul %H:%M")
    business = @booking.business.name

    body = if user == @booking.business.owner
      owner_notification_body(appointment, business)
    else
      customer_notification_body(appointment, business)
    end

    [ title, body ]
  end

  def owner_notification_body(appointment, business)
    case @event
    when :confirmation
      "Booking baru dari #{@booking.user.full_name} di #{business}, terjadwal #{appointment}."
    when :cancellation
      "Booking #{@booking.reference} dari #{@booking.user.full_name} di #{business} dibatalkan."
    when :reschedule
      "Jadwal booking #{@booking.reference} dari #{@booking.user.full_name} di #{business} diubah menjadi #{appointment}."
    end
  end

  def customer_notification_body(appointment, business)
    case @event
    when :confirmation
      "Booking #{@booking.reference} di #{business} tercatat untuk #{appointment}."
    when :cancellation
      "Booking #{@booking.reference} di #{business} berhasil dibatalkan."
    when :reschedule
      "Jadwal booking #{@booking.reference} di #{business} diubah menjadi #{appointment}."
    end
  end
end

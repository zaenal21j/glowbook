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
      BookingMailer.with(booking: @booking, recipient: recipient, locale: I18n.locale).public_send(@event).deliver_later
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
    title_key = if @event == :confirmation && user == @booking.business.owner
      "booking_email.new_booking"
    else
      "booking_email.#{@event == :confirmation ? 'booking_created' : @event == :cancellation ? 'booking_cancelled' : 'booking_rescheduled'}"
    end
    title = I18n.t(title_key)
    appointment = I18n.t("booking_email.appointment_format", date: I18n.l(@booking.start_time.to_date, format: :long), time: I18n.l(@booking.start_time, format: "%H:%M"))
    business = @booking.business.name

    body = if user == @booking.business.owner
      owner_notification_body(appointment, business)
    else
      customer_notification_body(appointment, business)
    end

    [ title, body ]
  end

  def owner_notification_body(appointment, business)
    key = "booking_email.owner_#{@event}"
    I18n.t(key, reference: @booking.reference, customer: @booking.user.full_name, business: business, appointment: appointment)
  end

  def customer_notification_body(appointment, business)
    key = "booking_email.customer_#{@event}"
    I18n.t(key, reference: @booking.reference, business: business, appointment: appointment)
  end
end

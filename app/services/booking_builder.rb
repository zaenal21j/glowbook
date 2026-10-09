class BookingBuilder
  # Checks availability before creating a booking in a DB transaction. The
  # tstzrange EXCLUDE constraint handles concurrent requests for the same staff.

  def initialize(user:, business:, service_ids:, staff_id: nil, start_time:, payment_method: nil)
    @user = user
    @business = business
    @service_ids = Array(service_ids).map(&:to_i).uniq
    @staff_id = staff_id
    @start_time = start_time
    @payment_method = payment_method.presence || "pay_at_venue"
  end

  def call
    services = Service.active.where(id: @service_ids, business_id: @business.id).order(:id).to_a
    return BookingResult.new(error: I18n.t("alerts.booking_builder.service_not_found")) if services.empty? || services.size != @service_ids.count
    return BookingResult.new(error: I18n.t("alerts.booking_builder.time_unavailable")) unless @start_time.respond_to?(:to_date)

    @staff_error = nil
    staff = resolve_staff(services)
    return BookingResult.new(error: @staff_error) if staff.nil? && @staff_error.present?
    return BookingResult.new(error: I18n.t("alerts.booking_builder.time_unavailable")) if staff.nil?

    unless sequence_available?(services, staff)
      return BookingResult.new(error: I18n.t("alerts.booking_builder.time_unavailable"))
    end

    end_time = @start_time + services.sum(&:duration_minutes).minutes

    Booking.transaction(requires_new: true) do
      booking = Booking.create!(
        user: @user,
        business: @business,
        start_time: @start_time,
        end_time: end_time,
        total_amount: services.sum(&:price),
        payment_method: @payment_method,
        status: :confirmed
      )

      cursor = @start_time
      services.each do |service|
        BookingItem.create!(
          booking: booking,
          service: service,
          staff: staff,
          price: service.price,
          duration_minutes: service.duration_minutes,
          during: cursor...(cursor + service.duration_minutes.minutes)
        )
        cursor += service.duration_minutes.minutes
      end

      # Reload supaya asosiasi (booking_items) tidak stale di memori
      # — item dibuat SETELAH booking, dan validasi saat create bisa
      # memuat asosiasi kosong ke cache objek.
      BookingResult.new(booking: booking.reload)
    end
  rescue ActiveRecord::RecordInvalid => e
    BookingResult.new(error: e.record.errors.full_messages.to_sentence)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::ExclusionViolation => e
    if e.message.include?("no_overlapping_bookings")
      BookingResult.new(error: I18n.t("alerts.booking_builder.slot_taken"))
    else
      BookingResult.new(error: I18n.t("alerts.booking_builder.save_failed"))
    end
  end

  private

  # An explicitly chosen staff must offer every selected service; if the
  # choice is invalid we stop with an error instead of silently booking
  # another staff member. Otherwise pick any free qualified staff.
  def resolve_staff(services)
    if @staff_id.present?
      staff = Staff.active.find_by(id: @staff_id, business_id: @business.id)
      if staff.nil?
        @staff_error = I18n.t("alerts.booking_builder.staff_not_found")
        return nil
      end
      unless services.all? { |s| staff.services.include?(s) }
        @staff_error = I18n.t("alerts.booking_builder.staff_not_qualified")
        return nil
      end
      return staff
    end

    candidates = services.map { |s| s.staff.active.to_a }.reduce(:&) || []
    candidates.find { |st| sequence_free?(services, st) }
  end

  # Every service must slot cleanly back-to-back for this staff member.
  def sequence_available?(services, staff)
    sequence_free?(services, staff)
  end

  def sequence_free?(services, staff)
    BookingSequenceAvailability.new(business: @business, services: services,
                                    date: @start_time.to_date, staff: staff).available_at?(@start_time)
  end
end

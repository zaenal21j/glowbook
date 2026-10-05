class BookingBuilder
  # Creates a booking within a DB transaction; relies on the tstzrange EXCLUDE
  # constraint for double-booking prevention and re-validates availability
  # inside the critical section.

  def initialize(user:, business:, service_ids:, staff_id: nil, start_time:, payment_method: nil)
    @user = user
    @business = business
    @service_ids = Array(service_ids).map(&:to_i).uniq
    @staff_id = staff_id
    @start_time = start_time
    @payment_method = payment_method.presence || "pay_at_venue"
  end

  def call
    services = Service.active.where(id: @service_ids, business_id: @business.id).order(:id)
    return BookingResult.new(error: "Layanan tidak ditemukan") if services.count != @service_ids.count

    @staff_error = nil
    staff = resolve_staff(services)
    return BookingResult.new(error: @staff_error) if staff.nil? && @staff_error.present?
    return BookingResult.new(error: "Waktu tidak tersedia. Silakan pilih jadwal lain.") if staff.nil?

    unless sequence_available?(services, staff)
      return BookingResult.new(error: "Waktu tidak tersedia. Silakan pilih jadwal lain.")
    end

    end_time = @start_time + services.sum(:duration_minutes).minutes

    Booking.transaction do
      booking = Booking.create!(
        user: @user,
        business: @business,
        start_time: @start_time,
        end_time: end_time,
        total_amount: services.sum(:price),
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
      BookingResult.new(error: "Jadwal baru saja diambil orang lain. Silakan pilih waktu lain.")
    else
      BookingResult.new(error: "Terjadi kesalahan saat menyimpan booking.")
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
        @staff_error = "Staff tidak ditemukan."
        return nil
      end
      unless services.all? { |s| staff.services.include?(s) }
        @staff_error = "Staff yang dipilih tidak melayani layanan ini."
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
    cursor = @start_time
    services.all? do |service|
      ok = Availability.new(
        business: @business,
        service: service,
        date: cursor.to_date,
        staff: staff
      ).available_at?(cursor)
      cursor += service.duration_minutes.minutes
      ok
    end
  end
end

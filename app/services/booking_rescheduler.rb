class BookingRescheduler
  class Unavailable < StandardError; end

  def initialize(booking:, start_time:)
    @booking = booking
    @start_time = start_time
  end

  def call
    @booking.with_lock(requires_new: true) do
      raise Unavailable unless @booking.reschedulable? && @start_time.respond_to?(:to_date)

      availability = BookingSequenceAvailability.new(business: @booking.business,
        booking: @booking, date: @start_time.to_date)
      raise Unavailable unless availability.available_at?(@start_time)

      items = @booking.booking_items.order(:during, :id).to_a
      # Release our old ranges within this transaction so moving earlier cannot
      # collide with another item belonging to this same appointment.
      @booking.booking_items.update_all(during: nil, updated_at: Time.current)
      cursor = @start_time
      items.each do |item|
        finish = cursor + item.duration_minutes.minutes
        item.update!(during: cursor...finish)
        cursor = finish
      end
      @booking.update!(start_time: @start_time, end_time: cursor)
    end
    BookingResult.new(booking: @booking.reload)
  rescue Unavailable, ActiveRecord::RecordInvalid
    BookingResult.new(error: I18n.t("alerts.booking.slot_taken"))
  rescue ActiveRecord::ExclusionViolation, ActiveRecord::RecordNotUnique
    BookingResult.new(error: I18n.t("alerts.booking.slot_taken"))
  end
end

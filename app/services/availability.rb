# Availability engine: computes bookable start times for a service on a given
# date, respecting business hours, staff schedules, breaks, blocked times, and
# existing bookings. All times are computed in the app timezone (Asia/Jakarta).

class Availability
  SLOT_GRANULARITY = 30.minutes

  attr_reader :date, :staff_ids, :duration_minutes

  def initialize(business:, service:, date:, staff: nil, duration_minutes: nil, excluding_booking: nil)
    @business = business
    @service = service
    @date = date
    @staff = staff
    @duration_minutes = duration_minutes || service.duration_minutes
    @excluding_booking = excluding_booking
    eligible_ids = eligible_staff_ids
    @staff_ids = staff ? eligible_ids & [staff.id] : eligible_ids
  end

  # Returns array of { time:, staff_ids: } hashes for each bookable start time
  def slots
    @slots ||= compute_slots
  end

  def available_at?(time)
    slots.any? { |s| s[:time] == time }
  end

  def has_availability?
    slots.any?
  end

  def staff_available_at?(time)
    slot = slots.find { |s| s[:time] == time }
    slot ? slot[:staff_ids] : []
  end

  # Later services in one appointment may begin between the displayed slots.
  # They still need to fit completely inside the day's available intervals.
  def staff_available_during(time)
    return [] if time.nil? || time.to_date != date || time <= Time.current

    window = business_window
    finish = time + duration_minutes.minutes
    return [] if window.nil? || time < window.first || finish > window.last

    staff_ids.select { |sid| staff_free?(sid, time, finish) }
  end

  private

  def compute_slots
    return [] unless date >= Date.current

    window = business_window
    return [] if window.nil?

    candidates = []

    slot_time = window.first
    last_start = window.last - duration_minutes.minutes
    while slot_time <= last_start
      available_staff = staff_available_during(slot_time)
      if available_staff.any?
        candidates << { time: slot_time, staff_ids: available_staff }
      end
      slot_time += SLOT_GRANULARITY
    end

    candidates
  end

  def business_window
    hour = business_hours.find_by(weekday: date.wday)
    return nil if hour.nil? || hour.closed?

    base = day_base
    [base + hour.open_minute.minutes, base + hour.close_minute.minutes]
  end

  def day_base
    @day_base ||= Time.zone.local(date.year, date.month, date.day)
  end

  def business_hours
    @business.business_hours
  end

  def eligible_staff_ids
    @business.staff.active.joins(:services).where(services: { id: @service.id }).distinct.ids
  end

  def staff_free?(staff_id, start, finish)
    working_hours?(staff_id, start, finish) &&
      !on_break?(staff_id, start, finish) &&
      !blocked?(staff_id, start, finish) &&
      !booked?(staff_id, start, finish)
  end

  def working_hours?(staff_id, start, finish)
    covered_until = minute_of_day(start)
    StaffSchedule.where(staff_id: staff_id, weekday: date.wday).order(:start_minute)
                 .pluck(:start_minute, :end_minute).each do |opens, closes|
      next if closes <= covered_until
      break if opens > covered_until

      covered_until = closes
      return true if covered_until >= minute_of_day(finish)
    end
    false
  end

  def on_break?(staff_id, start, finish)
    StaffBreak.where(staff_id: staff_id, weekday: date.wday)
              .where("start_minute < ? AND end_minute > ?", minute_of_day(finish), minute_of_day(start))
              .exists?
  end

  def blocked?(staff_id, start, finish)
    BlockedTime.overlapping(start...finish)
               .for_staff(staff_id)
               .where(business_id: @business.id)
               .exists?
  end

  def booked?(staff_id, start, finish)
    scope = BookingItem.active
               .joins(:booking)
               .where(staff_id: staff_id)
               .where(bookings: { business_id: @business.id, status: %w[pending confirmed] })
               .where("booking_items.during && tstzrange(?, ?, '[)')", start, finish)
    scope = scope.where.not(booking_id: @excluding_booking.id) if @excluding_booking
    scope.exists?
  end

  def minute_of_day(time)
    ((time - day_base) / 60).to_i
  end
end

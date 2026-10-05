# Availability engine: computes bookable start times for a service on a given
# date, respecting business hours, staff schedules, breaks, blocked times, and
# existing bookings. All times are computed in the app timezone (Asia/Jakarta).

class Availability
  SLOT_GRANULARITY = 30.minutes

  attr_reader :date, :staff_ids, :duration_minutes

  def initialize(business:, service:, date:, staff: nil)
    @business = business
    @service = service
    @date = date
    @staff = staff
    @duration_minutes = service.duration_minutes
    @staff_ids = staff ? [staff.id] : eligible_staff_ids
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

  private

  def compute_slots
    return [] unless date >= Date.current

    window = business_window
    return [] if window.nil?

    day_base = Time.zone.local(date.year, date.month, date.day)
    candidates = []

    slot_time = window.first
    last_start = window.last - duration_minutes.minutes
    # Slots already elapsed today can no longer be booked.
    earliest = date == Date.current ? Time.zone.now : nil
    while slot_time <= last_start
      available_staff = staff_ids.select do |sid|
        staff_free?(sid, slot_time, slot_time + duration_minutes.minutes)
      end
      if available_staff.any? && (earliest.nil? || slot_time > earliest)
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
    @business.staff.joins(:services).where(services: { id: @service.id }).ids
  end

  def staff_free?(staff_id, start, finish)
    working_hours?(staff_id, start, finish) &&
      !on_break?(staff_id, start, finish) &&
      !blocked?(staff_id, start, finish) &&
      !booked?(staff_id, start, finish)
  end

  def working_hours?(staff_id, start, finish)
    schedule = StaffSchedule.find_by(staff_id: staff_id, weekday: date.wday)
    return false if schedule.nil?

    start >= day_base + schedule.start_minute.minutes &&
      finish <= day_base + schedule.end_minute.minutes
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
    BookingItem.active
               .joins(:booking)
               .where(staff_id: staff_id)
               .where(bookings: { business_id: @business.id, status: %w[pending confirmed] })
               .where("booking_items.during && tstzrange(?, ?, '[)')", start, finish)
               .exists?
  end

  def minute_of_day(time)
    ((time - day_base) / 60).to_i
  end
end

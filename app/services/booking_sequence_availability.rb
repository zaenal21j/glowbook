# Checks a complete appointment. New bookings use one qualified staff member
# for every service; rescheduling preserves each item's staff and sold duration.
class BookingSequenceAvailability
  def initialize(business:, date:, services: nil, staff: nil, booking: nil)
    @booking = booking
    @segments = if booking
      booking.booking_items.order(:during, :id).includes(:service, :staff).map do |item|
        [item.service, item.staff, item.duration_minutes]
      end
    else
      Array(services).map { |service| [service, staff, service.duration_minutes] }
    end
    @engines = @segments.map do |service, member, duration|
      Availability.new(business: business, service: service, date: date, staff: member,
                       duration_minutes: duration, excluding_booking: booking)
    end
  end

  def slots
    @slots ||= begin
      if @engines.empty? || (@booking && @segments.any? { |_, member, _| member.nil? })
        []
      else
        @engines.first.slots.filter_map do |slot|
          members = sequence_staff_ids(slot[:time])
          { time: slot[:time], staff_ids: members } if members.any?
        end
      end
    end
  end

  def available_at?(time)
    staff_available_at?(time).any?
  end

  def staff_available_at?(time)
    slots.find { |slot| slot[:time] == time }&.fetch(:staff_ids) || []
  end

  private

  def sequence_staff_ids(time)
    common_staff = nil
    assigned_staff = []
    @engines.each_with_index do |engine, index|
      members = engine.staff_available_during(time)
      return [] if members.empty?

      if @booking
        assigned_staff.concat(members)
      else
        common_staff = common_staff ? common_staff & members : members
        return [] if common_staff.empty?
      end
      time += @segments[index].last.minutes
    end
    @booking ? assigned_staff.uniq : common_staff
  end
end

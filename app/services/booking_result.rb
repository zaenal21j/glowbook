# Result object returned by booking operations.
# Usage: result = CreateBooking.new(...).call
#        result.ok? / result.booking / result.error

class BookingResult
  attr_reader :booking, :error

  def initialize(booking: nil, error: nil)
    @booking = booking
    @error = error
  end

  def ok?
    @error.nil?
  end
end

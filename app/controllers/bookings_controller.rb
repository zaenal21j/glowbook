class BookingsController < ApplicationController
  before_action :set_booking, only: %i[show cancel reschedule update_schedule]
  before_action :authorize_owner!, only: %i[show cancel reschedule update_schedule]

  def show
    @latest_payment_attempt = @booking.payment_attempts.latest_first.first
  end

  def cancel
    @booking.cancel!
    BookingNotificationDelivery.new(booking: @booking, event: :cancellation).call
    redirect_to booking_path(@booking.reference), notice: "Booking berhasil dibatalkan."
  rescue ActiveRecord::RecordInvalid
    redirect_to booking_path(@booking.reference), alert: "Booking tidak dapat dibatalkan."
  end

  def reschedule
    return redirect_to booking_path(@booking.reference), alert: "Booking ini tidak lagi dapat diubah jadwal." unless @booking.reschedulable?

    @month = (@booking.start_time.to_date.beginning_of_month)
    @calendar_days = build_calendar(@month)
    @slots = []
    if params[:date].present?
      date = Date.parse(params[:date]) rescue nil
      if date
        @selected_date = date
        @slots = Availability.new(
          business: @booking.business,
          service: @booking.booking_items.first&.service,
          date: date,
          staff: @booking.booking_items.first&.staff
        ).slots
      end
    end
  end

  def update_schedule
    return redirect_to booking_path(@booking.reference), alert: "Booking ini tidak lagi dapat diubah jadwal." unless @booking.reschedulable?

    date = Date.parse(params[:date]) rescue nil
    time = Time.zone.parse(params[:time]) rescue nil
    if date.nil? || time.nil?
      return redirect_to reschedule_booking_path(@booking), alert: "Pilih tanggal dan waktu baru."
    end

    @booking.with_lock do
      raise ActiveRecord::RecordInvalid, @booking unless @booking.reschedulable?

      @booking.booking_items.update_all(during: nil, updated_at: Time.current)
      new_end = time + @booking.duration_minutes.minutes
      @booking.update!(start_time: time, end_time: new_end)
      @booking.booking_items.each do |item|
        item.update!(during: [ time, new_end ])
      end
    end

    BookingNotificationDelivery.new(booking: @booking, event: :reschedule).call
    redirect_to booking_path(@booking.reference), notice: "Jadwal booking berhasil diubah."
  rescue ActiveRecord::RecordNotUnique
    redirect_to reschedule_booking_path(@booking), alert: "Jadwal baru saja diambil orang lain. Pilih waktu lain."
  rescue ActiveRecord::RecordInvalid
    redirect_to booking_path(@booking.reference), alert: "Booking ini tidak lagi dapat diubah jadwal."
  end

  private

  def set_booking
    @booking = Booking.find_by!(reference: params[:reference] || params[:id])
  end

  def authorize_owner!
    return if @booking.user == current_user || current_user&.admin? || @booking.business.owner == current_user

    redirect_to root_path, alert: "Anda tidak memiliki akses ke booking ini."
  end

  def build_calendar(month_start)
    first_wday = (month_start.wday + 6) % 7
    cells = Array.new(first_wday) { nil }
    cells += (1..month_start.end_of_month.day).map { |d| month_start + (d - 1) }
    cells << nil while cells.size % 7 != 0
    cells.each_slice(7).to_a
  end
end

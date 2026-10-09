# Multi-step booking flow: Layanan → Staff → Tanggal → Waktu → Konfirmasi.
# State is kept in the session; availability comes from the Availability engine;
# persistence goes through BookingBuilder with double-booking protection.

class BookingsFlowController < ApplicationController
  STEPS = %w[layanan staff tanggal waktu konfirmasi].freeze

  before_action :set_business
  before_action :require_customer!, except: []
  before_action :init_flow, only: [ :new, :show, :update ]

  # GET /b/:slug/book           -> step 1 (layanan)
  # GET /b/:slug/book/step/:step -> resume a step
  def new
    session[:booking_flow] = { "business_id" => @business.id, "service_ids" => [], "staff_id" => nil, "date" => nil, "time" => nil }
    @step = "layanan"
    load_step_data
    render :new
  end

  def show
    step = params[:step]
    return redirect_to business_book_path(@business.slug) unless STEPS.include?(step)

    @step = step
    return unless flow_ready?
    load_step_data
    render :new
  end

  # PATCH/POST — advance from a step, storing selections in session
  def update
    @step = params[:step]
    return redirect_to business_book_path(@business.slug) unless STEPS.include?(@step)
    return unless flow_ready?

    case @step
    when "layanan"
      ids = Array(params[:service_ids]).map(&:to_i).reject(&:zero?)
      valid_ids = @business.services.active.where(id: ids).order(:id).ids
      if valid_ids.empty? || valid_ids.size != ids.uniq.size
        redirect_to business_book_path(@business.slug), alert: t("alerts.booking.select_service") and return
      end
      flow["service_ids"] = valid_ids
      flow["staff_id"] = nil
      flow["date"] = nil
      flow["time"] = nil
      redirect_to business_book_step_path(@business.slug, "staff")
    when "staff"
      chosen = params[:staff_id].presence
      member = @business.staff.active.find_by(id: chosen) if chosen
      if chosen && (member.nil? || (selected_services.ids - member.service_ids).any?)
        return redirect_to business_book_step_path(@business.slug, "staff"), alert: t("alerts.booking_builder.staff_not_qualified")
      end
      flow["staff_id"] = member&.id
      flow["time"] = nil
      redirect_to business_book_step_path(@business.slug, "tanggal")
    when "tanggal"
      date = parse_date(params[:date])
      if date && (Date.current..Date.current + 60.days).cover?(date)
        flow["date"] = date.iso8601
        flow["time"] = nil
        redirect_to business_book_step_path(@business.slug, "waktu")
      else
        redirect_to business_book_step_path(@business.slug, "tanggal"), alert: t("alerts.booking.select_date")
      end
    when "waktu"
      time = parse_time(params[:time])
      if time && time.to_date == flow_date && sequence_availability.available_at?(time)
        flow["time"] = time.iso8601
        redirect_to business_book_confirmation_path(@business.slug)
      else
        redirect_to business_book_step_path(@business.slug, "waktu"), alert: t("alerts.booking.select_time")
      end
    when "konfirmasi"
      complete
    end
  end

  # GET — confirmation review page
  def confirmation
    @step = "konfirmasi"
    return unless flow_ready?
    load_step_data
    render :new
  end

  # POST — persist the booking
  def complete
    @step = "konfirmasi"
    return unless flow_ready?

    payment_method = params[:payment_method].presence || flow["payment_method"] || "pay_at_venue"
    unless Booking::PAYMENT_METHODS.include?(payment_method)
      return redirect_to business_book_confirmation_path(@business.slug), alert: t("alerts.booking.invalid_payment_method")
    end
    if payment_method == "online_transfer" && !Rails.configuration.x.midtrans_enabled
      return redirect_to business_book_confirmation_path(@business.slug), alert: t("alerts.booking.online_payment_unavailable")
    end
    if payment_method == "online_transfer" && @business.services.active.where(id: flow["service_ids"]).sum(:price) <= 0
      return redirect_to business_book_confirmation_path(@business.slug), alert: t("alerts.booking.online_payment_positive_total")
    end

    result = BookingBuilder.new(
      user: current_user,
      business: @business,
      service_ids: flow["service_ids"],
      staff_id: flow["staff_id"],
      start_time: flow_start_time,
      payment_method: payment_method
    ).call

    if result.ok?
      session.delete(:booking_flow)
      BookingNotificationDelivery.new(booking: result.booking, event: :confirmation).call
      redirect_to booking_path(result.booking.reference)
    else
      redirect_to business_book_confirmation_path(@business.slug), alert: result.error
    end
  end

  private

  def set_business
    @business = Business.active.find_by!(slug: params[:slug])
  end

  def flow
    state = session[:booking_flow]
    unless state.is_a?(Hash) && state["business_id"].to_i == @business.id
      state = session[:booking_flow] = { "business_id" => @business.id }
    end
    state
  end

  def init_flow
    flow
  end

  def load_step_data
    case @step
    when "layanan"
      @services = @business.services.active.ordered.includes(:category)
    when "staff"
      @staff = @business.staff.active.ordered.includes(:services)
    when "tanggal"
      @selected_service_ids = flow["service_ids"] || []
      @month = parse_month
      @calendar_days = build_calendar(@month)
    when "waktu"
      date = flow_date
      @slots = if date
        sequence_availability.slots
      else
        []
      end
    when "konfirmasi"
      @services = selected_services
      @staff = flow_staff
      @date = flow_date
      @time = flow_time
      @total = @services.sum(:price)
      @total_duration = @services.sum(:duration_minutes)
    end
  end

  def flow_staff
    flow["staff_id"] ? @business.staff.active.find_by(id: flow["staff_id"]) : nil
  end

  def flow_date
    parse_date(flow["date"])
  end

  def flow_time
    parse_time(flow["time"])
  end

  def flow_start_time
    flow_time
  end

  def parse_month
    month = parse_date(params[:date]) || flow_date || Date.current
    month = Date.current unless (Date.current.beginning_of_month..(Date.current + 60.days).end_of_month).cover?(month)
    month.beginning_of_month
  end

  def selected_services
    @business.services.active.where(id: Array(flow["service_ids"])).order(:id)
  end

  def sequence_availability
    BookingSequenceAvailability.new(business: @business, services: selected_services,
                                     date: flow_date, staff: flow_staff)
  end

  def flow_ready?
    return true if @step == "layanan"

    ids = Array(flow["service_ids"])
    if ids.empty? || selected_services.count != ids.uniq.size
      redirect_to business_book_path(@business.slug), alert: t("alerts.booking.select_service")
    elsif flow["staff_id"].present? && (flow_staff.nil? || (selected_services.ids - flow_staff.service_ids).any?)
      # The staff step lets the customer replace an unavailable selection.
      return true if @step == "staff"
      redirect_to business_book_step_path(@business.slug, "staff"), alert: t("alerts.booking_builder.staff_not_qualified")
    elsif %w[waktu konfirmasi].include?(@step) && flow_date.nil?
      redirect_to business_book_step_path(@business.slug, "tanggal"), alert: t("alerts.booking.select_date")
    elsif @step == "konfirmasi" && (flow_time.nil? || flow_time.to_date != flow_date)
      redirect_to business_book_step_path(@business.slug, "waktu"), alert: t("alerts.booking.select_time")
    else
      return true
    end
    false
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def parse_time(value)
    Time.zone.iso8601(value.to_s).in_time_zone
  rescue ArgumentError, TypeError
    nil
  end

  def build_calendar(month_start)
    # Weeks of Date objects, Monday-first display, including leading blanks
    first_wday = (month_start.wday + 6) % 7 # Monday=0
    days_in_month = month_start.end_of_month.day
    cells = Array.new(first_wday) { nil }
    cells += (1..days_in_month).map { |d| month_start + (d - 1) }
    cells << nil while cells.size % 7 != 0
    cells.each_slice(7).to_a
  end
end

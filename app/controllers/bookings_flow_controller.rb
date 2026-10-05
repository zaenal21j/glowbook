# Multi-step booking flow: Layanan → Staff → Tanggal → Waktu → Konfirmasi.
# State is kept in the session; availability comes from the Availability engine;
# persistence goes through BookingBuilder with double-booking protection.

class BookingsFlowController < ApplicationController
  STEPS = %w[layanan staff tanggal waktu konfirmasi].freeze

  before_action :set_business
  before_action :require_customer!, except: []
  before_action :init_flow, only: [:new, :show, :update]

  # GET /b/:slug/book           -> step 1 (layanan)
  # GET /b/:slug/book/step/:step -> resume a step
  def new
    session[:booking_flow] = { "service_ids" => [], "staff_id" => nil, "date" => nil, "time" => nil }
    @step = "layanan"
    load_step_data
    render :new
  end

  def show
    step = params[:step]
    return redirect_to business_book_path(@business.slug) unless STEPS.include?(step)

    @step = step
    load_step_data
    render :new
  end

  # PATCH/POST — advance from a step, storing selections in session
  def update
    @step = params[:step]
    return redirect_to business_book_path(@business.slug) unless STEPS.include?(@step)

    case @step
    when "layanan"
      ids = Array(params[:service_ids]).map(&:to_i).reject(&:zero?)
      valid_ids = @business.services.active.where(id: ids).ids
      if valid_ids.empty?
        redirect_to business_book_path(@business.slug), alert: "Pilih minimal satu layanan." and return
      end
      flow["service_ids"] = valid_ids
      flow["staff_id"] = nil
      flow["date"] = nil
      flow["time"] = nil
      redirect_to business_book_step_path(@business.slug, "staff")
    when "staff"
      flow["staff_id"] = params[:staff_id].presence&.to_i
      redirect_to business_book_step_path(@business.slug, "tanggal")
    when "tanggal"
      if params[:date].present?
        flow["date"] = params[:date]
        redirect_to business_book_step_path(@business.slug, "waktu")
      else
        redirect_to business_book_step_path(@business.slug, "tanggal"), alert: "Pilih tanggal kunjungan."
      end
    when "waktu"
      if params[:time].present?
        flow["time"] = params[:time]
        redirect_to business_book_confirmation_path(@business.slug)
      else
        redirect_to business_book_step_path(@business.slug, "waktu"), alert: "Pilih jam kunjungan."
      end
    when "konfirmasi"
      create_booking
    end
  end

  # GET — confirmation review page
  def confirmation
    @step = "konfirmasi"
    unless flow["service_ids"].present? && flow["date"].present? && flow["time"].present?
      return redirect_to business_book_path(@business.slug)
    end
    load_step_data
    render :new
  end

  # POST — persist the booking
  def complete
    unless flow["service_ids"].present? && flow["date"].present? && flow["time"].present?
      return redirect_to business_book_path(@business.slug)
    end

    result = BookingBuilder.new(
      user: current_user,
      business: @business,
      service_ids: flow["service_ids"],
      staff_id: flow["staff_id"],
      start_time: flow_start_time,
      payment_method: params[:payment_method] || flow["payment_method"]
    ).call

    if result.ok?
      session.delete(:booking_flow)
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
    session[:booking_flow] ||= {}
  end

  def init_flow
    session[:booking_flow] ||= {}
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
        Availability.new(business: @business, service: @business.services.active.find(flow["service_ids"].first), date: date, staff: flow_staff).slots
      else
        []
      end
    when "konfirmasi"
      @services = @business.services.active.where(id: flow["service_ids"])
      @staff = flow_staff
      @date = flow_date
      @time = flow_time
      @total = @services.sum(:price)
      @total_duration = @services.sum(:duration_minutes)
    end
  end

  def flow_staff
    flow["staff_id"] ? Staff.find_by(id: flow["staff_id"], business_id: @business.id) : nil
  end

  def flow_date
    return nil if flow["date"].blank?

    Date.parse(flow["date"])
  rescue Date::Error
    nil
  end

  def flow_time
    return nil if flow["time"].blank?

    Time.zone.parse(flow["time"])
  rescue ArgumentError
    nil
  end

  def flow_start_time
    flow_time || Time.zone.parse("#{flow['date']} #{flow['time']}")
  end

  def parse_month
    month = flow_date || Date.current
    month.beginning_of_month
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

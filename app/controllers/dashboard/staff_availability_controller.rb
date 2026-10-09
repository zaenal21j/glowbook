class Dashboard::StaffAvailabilityController < Dashboard::BaseController
  before_action :set_staff_member

  def show
    @schedule = @staff_member.staff_schedules.find(params[:shift_id]) if params[:shift_id].present?
    @staff_break = @staff_member.staff_breaks.find(params[:break_id]) if params[:break_id].present?
    load_view_data
  end

  def create_shift
    @schedule = @staff_member.staff_schedules.build(shift_params)
    save_shift
  end

  def update_shift
    @schedule = @staff_member.staff_schedules.find(params[:id])
    @schedule.assign_attributes(shift_params)
    save_shift
  end

  def destroy_shift
    @staff_member.staff_schedules.find(params[:id]).destroy!
    redirect_to dashboard_staff_availability_path(@staff_member), notice: t("scheduling.shift_deleted")
  end

  def create_break
    @staff_break = @staff_member.staff_breaks.build(break_params)
    save_break
  end

  def update_break
    @staff_break = @staff_member.staff_breaks.find(params[:id])
    @staff_break.assign_attributes(break_params)
    save_break
  end

  def destroy_break
    @staff_member.staff_breaks.find(params[:id]).destroy!
    redirect_to dashboard_staff_availability_path(@staff_member), notice: t("scheduling.break_deleted")
  end

  def copy_hours
    result = @staff_member.with_lock do
      if @staff_member.staff_schedules.exists?
        :already_configured
      else
        hours = @business.business_hours.where(closed: false).to_a
        hours.each do |hour|
          @staff_member.staff_schedules.create!(weekday: hour.weekday, start_minute: hour.open_minute, end_minute: hour.close_minute)
        end
        hours.size
      end
    end

    if result == :already_configured
      redirect_to dashboard_staff_availability_path(@staff_member), alert: t("scheduling.already_configured")
    elsif result.zero?
      redirect_to dashboard_staff_availability_path(@staff_member), alert: t("scheduling.no_business_hours")
    else
      redirect_to dashboard_staff_availability_path(@staff_member), notice: t("scheduling.hours_copied")
    end
  end

  private

  def set_staff_member
    @staff_member = @business.staff.find(params[:staff_id])
  end

  def load_view_data
    @schedules = @staff_member.staff_schedules.order(:weekday, :start_minute)
    @breaks = @staff_member.staff_breaks.order(:weekday, :start_minute)
    @schedule ||= @staff_member.staff_schedules.build(weekday: 1, start_minute: 540, end_minute: 1020)
    @staff_break ||= @staff_member.staff_breaks.build(weekday: 1, start_minute: 720, end_minute: 780)
  end

  def save_shift
    if @staff_member.with_lock { @schedule.save }
      redirect_to dashboard_staff_availability_path(@staff_member), notice: t("scheduling.shift_saved")
    else
      load_view_data
      render :show, status: :unprocessable_entity
    end
  end

  def save_break
    if @staff_break.save
      redirect_to dashboard_staff_availability_path(@staff_member), notice: t("scheduling.break_saved")
    else
      load_view_data
      render :show, status: :unprocessable_entity
    end
  end

  def shift_params
    params.require(:staff_schedule).permit(:weekday, :start_minute, :end_minute)
  end

  def break_params
    params.require(:staff_break).permit(:weekday, :start_minute, :end_minute)
  end
end

class Dashboard::BlockedTimesController < Dashboard::BaseController
  def index
    load_view_data
  end

  def edit
    @blocked_time = @business.blocked_times.find(params[:id])
    load_view_data
    render :index
  end

  def create
    @blocked_time = @business.blocked_times.build(blocked_time_params)
    save_block
  end

  def update
    @blocked_time = @business.blocked_times.find(params[:id])
    @blocked_time.assign_attributes(blocked_time_params)
    save_block
  end

  def destroy
    @business.blocked_times.find(params[:id]).destroy!
    redirect_to dashboard_blocked_times_path, notice: t("scheduling.blocks.deleted")
  end

  private

  def load_view_data
    @filter = %w[upcoming past all].include?(params[:filter]) ? params[:filter] : "upcoming"
    scope = @business.blocked_times.includes(:staff)
    scope = scope.where("end_time >= ?", Time.current) if @filter == "upcoming"
    scope = scope.where("end_time < ?", Time.current) if @filter == "past"
    @blocked_times = paginate(scope.order(start_time: :desc, id: :desc))
    @staff_members = @business.staff.ordered
    start_time = 1.day.from_now.change(min: 0, sec: 0)
    @blocked_time ||= @business.blocked_times.build(start_time: start_time, end_time: start_time + 1.hour)
  end

  def save_block
    if @blocked_time.save
      redirect_to dashboard_blocked_times_path, notice: t("scheduling.blocks.saved")
    else
      load_view_data
      render :index, status: :unprocessable_entity
    end
  end

  def blocked_time_params
    params.require(:blocked_time).permit(:staff_id, :reason, :start_time, :end_time)
  end
end

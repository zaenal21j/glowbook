class Admin::PaymentsController < Admin::BaseController
  def index
    @month = selected_month
    @status = PaymentAttempt::STATUSES.include?(params[:status]) ? params[:status] : nil

    period = @month.beginning_of_month.beginning_of_day..@month.end_of_month.end_of_day
    scope = PaymentAttempt.joins(booking: %i[user business])
                          .where("COALESCE(payment_attempts.settled_at, payment_attempts.created_at) BETWEEN ? AND ?", period.begin, period.end)

    if @status
      scope = scope.where(status: @status)
    end

    query = params[:q].to_s.strip
    if query.present?
      escaped_query = ActiveRecord::Base.sanitize_sql_like(query)
      scope = scope.where(
        "payment_attempts.order_id ILIKE :q OR payment_attempts.transaction_id ILIKE :q OR bookings.reference ILIKE :q OR users.name ILIKE :q OR users.email ILIKE :q OR businesses.name ILIKE :q",
        q: "%#{escaped_query}%"
      )
    end

    @payment_scope = scope.includes(booking: %i[user business])
                          .order(Arel.sql("payment_attempts.settled_at DESC NULLS LAST, payment_attempts.created_at DESC"))

    respond_to do |format|
      format.html { @payments = paginate(@payment_scope) }
      format.csv do
        send_data PaymentAttemptCsv.new(@payment_scope).render,
                  filename: "glowbook-payments-#{@month.strftime('%Y-%m')}.csv",
                  type: "text/csv; charset=utf-8"
      end
    end
  end

  private

  def selected_month
    return Date.current.beginning_of_month if params[:month].blank?

    Date.strptime(params[:month], "%Y-%m").beginning_of_month
  rescue Date::Error, ArgumentError
    Date.current.beginning_of_month
  end
end

# Aggregates booking counts and revenue per day for the admin chart.
# Fills missing days with zeros so the bar chart stays continuous.
class AdminCharts
  def initialize(scope_date:)
    @range = scope_date
    @days = (@range.first..@range.last).to_a
  end

  def daily_counts
    @daily_counts ||= begin
      raw = Booking.where(start_time: range_start..range_end).group("date(start_time AT TIME ZONE 'Asia/Jakarta')").count
      fill(raw)
    end
  end

  def daily_revenue
    @daily_revenue ||= begin
      raw = Booking.where(start_time: range_start..range_end)
                   .where(status: %w[pending confirmed completed])
                   .group("date(start_time AT TIME ZONE 'Asia/Jakarta')")
                   .sum(:total_amount)
      fill(raw)
    end
  end

  def max_count
    daily_counts.values.max.to_i
  end

  def max_revenue
    daily_revenue.values.max.to_i
  end

  private

  def range_start
    @range.first.beginning_of_day
  end

  def range_end
    @range.last.end_of_day
  end

  def fill(raw)
    @days.index_with { |d| raw[d.to_date].to_i }
  end
end

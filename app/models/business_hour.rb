class BusinessHour < ApplicationRecord
  belongs_to :business

  validates :business, presence: true
  validates :weekday, presence: true, uniqueness: { scope: :business_id }, inclusion: { in: 0..6 }
  validates :open_minute, :close_minute, presence: true, numericality: { only_integer: true, in: 0..(24 * 60) }
  validates :closed, inclusion: { in: [true, false] }
  validate  :close_after_open, unless: :closed?

  def self.days
    %w[Minggu Senin Selasa Rabu Kamis Jumat Sabtu]
  end

  def day_name
    I18n.t("date.day_names")[weekday]
  end

  def open_time_string
    Time.at(open_minute * 60).utc.strftime("%H:%M")
  end

  def close_time_string
    Time.at(close_minute * 60).utc.strftime("%H:%M")
  end

  def open_today_label
    closed? ? I18n.t("scheduling.closed") : "#{open_time_string} - #{close_time_string}"
  end

  private

  def close_after_open
    return if open_minute.nil? || close_minute.nil? || open_minute < close_minute

    errors.add(:close_minute, I18n.t("scheduling.errors.end_after_start"))
  end
end

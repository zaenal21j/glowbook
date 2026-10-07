class UserNotification < ApplicationRecord
  EVENTS = %w[confirmation cancellation reschedule].freeze

  belongs_to :user

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  validates :booking_reference, :title, :body, presence: true
  validates :event, inclusion: { in: EVENTS }

  def unread?
    read_at.nil?
  end
end

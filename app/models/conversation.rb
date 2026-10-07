class Conversation < ApplicationRecord
  belongs_to :business
  belongs_to :customer, class_name: "User"
  has_many :chat_messages, dependent: :destroy

  validates :business, presence: true
  validates :customer, presence: true
  validates :customer_id, uniqueness: { scope: :business_id }

  scope :recent, -> { order(Arel.sql("COALESCE(conversations.last_message_at, conversations.created_at) DESC")) }

  def participant?(user)
    return false unless user
    return true if customer_id == user.id || business.owner_id == user.id

    business.staff.active.exists?(user_id: user.id)
  end

  def unread_count_for(user)
    chat_messages.where.not(sender_id: user.id).where(read_at: nil).count
  end
end

class ChatMessage < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, class_name: "User"

  before_validation :trim_body
  after_create :touch_conversation

  validates :body, presence: true, length: { maximum: 2_000 }
  validate :sender_must_be_a_participant

  private

  def trim_body
    self.body = body.to_s.strip
  end

  def sender_must_be_a_participant
    return if conversation&.participant?(sender)

    errors.add(:sender, I18n.t("validation.chat_participant"))
  end

  def touch_conversation
    conversation.update_column(:last_message_at, created_at)
  end
end

class ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation, only: %i[show create poll]
  before_action :require_participant!, only: %i[show create poll]

  def index
    if params[:audience] == "business"
      @business = business_for_current_user
      return redirect_to root_path, alert: "Anda tidak memiliki akses ke pesan bisnis." unless @business

      @conversations = @business.conversations.includes(:customer).recent.limit(100)
    else
      @conversations = current_user.conversations.includes(:business).recent.limit(100)
    end

    @unread_counts = ChatMessage.where(conversation_id: @conversations.select(:id))
                                .where.not(sender_id: current_user.id)
                                .where(read_at: nil)
                                .group(:conversation_id)
                                .count
  end

  def start
    business = Business.active.find_by!(slug: params[:slug])
    if business.owner_id == current_user.id || business.staff.exists?(user_id: current_user.id)
      return redirect_to business_detail_path(business.slug), alert: "Anda tidak dapat mengirim pesan ke bisnis sendiri."
    end

    conversation = Conversation.find_or_create_by!(business: business, customer: current_user)
    redirect_to chat_path(conversation)
  rescue ActiveRecord::RecordNotUnique
    conversation = Conversation.find_by!(business: business, customer: current_user)
    redirect_to chat_path(conversation)
  end

  def show
    mark_unread_messages_as_read
    @messages = @conversation.chat_messages.includes(:sender).order(:id).last(100) || []
    @message = @conversation.chat_messages.build
    @last_message_id = @messages.last&.id || 0
  end

  def create
    @message = @conversation.chat_messages.build(message_params.merge(sender: current_user))
    if @message.save
      redirect_to chat_path(@conversation), status: :see_other
    else
      mark_unread_messages_as_read
      @messages = @conversation.chat_messages.includes(:sender).order(:id).last(100) || []
      @last_message_id = @messages.last&.id || 0
      render :show, status: :unprocessable_entity
    end
  end

  def poll
    after_id = [ params[:after_id].to_i, 0 ].max
    messages = @conversation.chat_messages.includes(:sender).where("chat_messages.id > ?", after_id).order(:id).limit(100)
    mark_unread_messages_as_read

    render json: messages.map { |message|
      {
        id: message.id,
        sender: message.sender.full_name,
        mine: message.sender_id == current_user.id,
        body: message.body,
        time: I18n.l(message.created_at, format: "%d %b %Y, %H:%M")
      }
    }
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
  end

  def require_participant!
    head :not_found unless @conversation.participant?(current_user)
  end

  def business_for_current_user
    return current_user.businesses.first if current_user.business_owner?
    return current_user.staff_member.business if current_user.staff_member&.active?

    nil
  end

  def message_params
    params.require(:chat_message).permit(:body)
  end

  def mark_unread_messages_as_read
    @conversation.chat_messages.where.not(sender_id: current_user.id).where(read_at: nil)
                 .update_all(read_at: Time.current, updated_at: Time.current)
  end
end

class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable,
         :validatable, :omniauthable, omniauth_providers: [ :facebook ]

  ROLE_COLORS = {}.freeze

  enum :role, { customer: 0, business_owner: 1, staff: 2, admin: 9 }, default: :customer

  has_many :businesses, foreign_key: :owner_id, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :favorites, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :conversations, foreign_key: :customer_id, dependent: :destroy
  has_many :chat_messages, foreign_key: :sender_id, dependent: :destroy
  has_many :user_notifications, dependent: :destroy
  has_one :staff_member, class_name: "Staff", dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
  validates :phone, allow_blank: true, format: { with: /\A\+?[0-9]{8,15}\z/ }
  validates :uid, uniqueness: { scope: :provider }, allow_nil: true

  scope :customers, -> { where(role: :customer) }
  scope :owners, -> { where(role: :business_owner) }

  def self.from_facebook(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create! do |user|
      user.email = auth.info.email.presence || "fb-#{auth.uid}@glowbook.id"
      user.name = auth.info.name.presence || I18n.t("display.facebook_user")
      user.password = Devise.friendly_token[0, 20]
      user.remote_avatar_url = auth.info.image if auth.info.image.present?
    end
  end

  def business_owner?
    super || businesses.exists?
  end

  def has_retained_records?
    businesses.exists? || staff_member.present? || bookings.exists? || reviews.exists? ||
      conversations.exists? || chat_messages.exists?
  end

  def send_devise_notification(notification, *args)
    devise_mailer.public_send(notification, self, *args).deliver_later
  end

  def full_name
    name.presence || email.split("@").first.titleize
  end

  def initial
    full_name[0].upcase
  end
end

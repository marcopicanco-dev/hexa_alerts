class Fan < ApplicationRecord
  has_many :alert_subscriptions, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_validation { self.email = email.to_s.strip.downcase.presence }
end

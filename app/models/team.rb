class Team < ApplicationRecord
  has_many :home_matches, class_name: "Match", foreign_key: :home_team_id, inverse_of: :home_team, dependent: :restrict_with_error
  has_many :away_matches, class_name: "Match", foreign_key: :away_team_id, inverse_of: :away_team, dependent: :restrict_with_error
  has_many :match_events, dependent: :restrict_with_error
  has_many :alert_subscriptions, dependent: :destroy

  validates :fifa_code, presence: true, uniqueness: { case_sensitive: false }, format: { with: /\A[A-Z]{3}\z/ }
  validates :name, :country, presence: true

  before_validation { self.fifa_code = fifa_code.to_s.upcase.presence }
end

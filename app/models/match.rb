class Match < ApplicationRecord
  STATUSES = %w[scheduled live finished postponed cancelled].freeze

  belongs_to :home_team, class_name: "Team", inverse_of: :home_matches
  belongs_to :away_team, class_name: "Team", inverse_of: :away_matches
  has_many :match_events, dependent: :destroy
  has_many :alert_subscriptions, dependent: :destroy
  has_many :external_references, class_name: "MatchExternalReference", dependent: :destroy

  validates :external_id, :starts_at, presence: true
  validates :external_id, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :home_score, :away_score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :clock_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :different_teams

  def team?(team) = home_team_id == team.id || away_team_id == team.id
  def live? = status == "live"

  def self.find_by_external_id(external_id)
    find_by(external_id:) || joins(:external_references).find_by(match_external_references: { external_id: })
  end

  def self.find_by_external_id!(external_id) = find_by_external_id(external_id) || raise(ActiveRecord::RecordNotFound)

  def stat(key, side)
    statistics.dig(key.to_s, side.to_s)
  end

  def win_probability(side)
    win_probabilities.fetch(side.to_s, 0)
  end

  private

  def different_teams
    errors.add(:away_team, "must be different from home team") if home_team_id == away_team_id
  end
end

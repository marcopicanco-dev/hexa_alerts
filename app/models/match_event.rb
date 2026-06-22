class MatchEvent < ApplicationRecord
  KINDS = %w[goal yellow_card red_card var_review match_started match_update match_finished].freeze

  belongs_to :match
  belongs_to :team

  validates :external_id, :occurred_at, presence: true
  validates :external_id, uniqueness: true
  validates :kind, inclusion: { in: KINDS }
  validate :team_belongs_to_match

  private

  def team_belongs_to_match
    errors.add(:team, "must participate in the match") if match && team && !match.team?(team)
  end
end

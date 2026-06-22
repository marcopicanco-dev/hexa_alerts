class AlertSubscription < ApplicationRecord
  belongs_to :fan
  belongs_to :team, optional: true
  belongs_to :match, optional: true

  validates :event_kind, inclusion: { in: MatchEvent::KINDS }, allow_blank: true
  validates :fan_id, uniqueness: { scope: %i[team_id match_id event_kind], message: "already has this alert" }
  validate :has_scope

  scope :active, -> { where(active: true) }
  scope :for_event, lambda { |event|
    where("team_id = :team_id OR match_id = :match_id", team_id: event.team_id, match_id: event.match_id)
      .where(event_kind: [ nil, "", event.kind ])
  }

  private

  def has_scope
    errors.add(:base, "choose a team or match") if team_id.blank? && match_id.blank?
  end
end

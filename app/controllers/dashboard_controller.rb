class DashboardController < ApplicationController
  def index
    @fans = Fan.order(:name)
    @fan = @fans.find { |fan| fan.id == params[:fan_id].to_i } || @fans.first
    status_priority = Arel.sql("CASE matches.status WHEN 'live' THEN 0 WHEN 'scheduled' THEN 1 WHEN 'postponed' THEN 2 ELSE 3 END")
    @matches = Match.includes(:home_team, :away_team).order(status_priority, :starts_at)
    @live_matches = @matches.select(&:live?)
    @teams = Team.order(:name)
    @subscriptions = @fan&.alert_subscriptions&.includes(:team, match: %i[home_team away_team])&.order(created_at: :desc) || []
    @events = relevant_events.limit(30)
  end

  private

  def relevant_events
    return MatchEvent.none unless @fan

    event_ids = @fan.alert_subscriptions.active.flat_map do |subscription|
      events = MatchEvent.where(team_id: subscription.team_id).or(MatchEvent.where(match_id: subscription.match_id))
      events = events.where(kind: subscription.event_kind) if subscription.event_kind.present?
      events.ids
    end

    MatchEvent.includes(:team, match: %i[home_team away_team]).where(id: event_ids)
      .order(occurred_at: :desc)
  end
end

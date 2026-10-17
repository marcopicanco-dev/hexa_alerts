class DashboardController < ApplicationController
  def index
    @summary = WorldCup2026::Summary.new
    @sync = CompetitionSync.recent.first
    @fans = Fan.order(:name)
    @fan = @fans.find { |fan| fan.id == params[:fan_id].to_i } || @fans.first
    status_priority = Arel.sql("CASE matches.status WHEN 'live' THEN 0 WHEN 'scheduled' THEN 1 WHEN 'postponed' THEN 2 ELSE 3 END")
    all_matches = Match.includes(:home_team, :away_team).order(status_priority, :starts_at)
    @all_matches = all_matches.to_a
    @live_matches = @all_matches.select(&:live?)
    @match_count = @all_matches.size
    @finished_match_count = @all_matches.count { |match| match.status == "finished" }
    @goal_count = @all_matches.sum { |match| match.home_score + match.away_score }
    @stage = params[:stage].to_s
    @stage = "knockout" if @stage.blank? && @summary.finished?
    @matches = case @stage
    when "knockout" then @all_matches.reject { |match| match.stage.in?(%w[group group_stage]) }.sort_by(&:starts_at).reverse
    when "group" then @all_matches.select { |match| match.stage.in?(%w[group group_stage]) }
    else @all_matches
    end
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

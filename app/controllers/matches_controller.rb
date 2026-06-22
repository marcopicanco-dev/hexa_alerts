class MatchesController < ApplicationController
  def show
    @match = Match.includes(:home_team, :away_team, match_events: :team).find(params[:id])
    @events = @match.match_events.order(occurred_at: :desc).limit(30)
  end
end

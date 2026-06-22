class ProcessMatchEventJob < ApplicationJob
  queue_as :match_events

  discard_on ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid do |job, error|
    Rails.logger.error(event: "match_event.discarded", job_id: job.job_id, error: error.message)
  end

  def perform(payload)
    data = payload.stringify_keys
    match = Match.find_by_external_id!(data.fetch("match_id"))
    team = Team.find_by!(fifa_code: data.fetch("team_code").upcase)
    event = persist_event(match, team, data)
    broadcast(event) if event
  end

  private

  def persist_event(match, team, data)
    event = nil

    match.with_lock do
      return if MatchEvent.exists?(external_id: data.fetch("event_id"))

      event = match.match_events.create!(
        external_id: data.fetch("event_id"),
        team:,
        kind: data.fetch("type"),
        occurred_at: Time.iso8601(data.fetch("occurred_at")),
        payload: data
      )
      update_match!(match, event, data)
    end

    event
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def update_match!(match, event, data)
    snapshot = snapshot_attributes(data)

    case event.kind
    when "goal"
      column = match.home_team_id == event.team_id ? :home_score : :away_score
      snapshot.merge!(column => match.public_send(column) + 1, status: "live")
    when "match_started"
      snapshot.reverse_merge!(status: "live", clock_seconds: 0, clock_running: true, clock_updated_at: Time.current)
    when "match_finished"
      snapshot.merge!(status: "finished", clock_running: false, clock_updated_at: Time.current)
    end

    match.update!(snapshot) if snapshot.any?
  end

  def broadcast(event)
    Turbo::StreamsChannel.broadcast_replace_to(
      "match_#{event.match_id}",
      target: "match-live-panel",
      partial: "matches/live_panel",
      locals: { match: event.match.reload }
    )

    return if event.kind == "match_update"

    MatchEventBroadcaster.new(event).call
  end

  def snapshot_attributes(data)
    attributes = {}
    attributes[:clock_seconds] = data["clock_seconds"].to_i if data.key?("clock_seconds")
    attributes[:clock_running] = ActiveModel::Type::Boolean.new.cast(data["clock_running"]) if data.key?("clock_running")
    attributes[:clock_updated_at] = Time.current if data.key?("clock_seconds") || data.key?("clock_running")
    attributes[:statistics] = data["statistics"] if data["statistics"].present?
    attributes[:win_probabilities] = data["win_probabilities"] if data["win_probabilities"].present?
    attributes
  end
end

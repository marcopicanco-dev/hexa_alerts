module FootballData
  class Importer
    Result = Data.define(:matches, :skipped)

    def initialize(client: Client.new)
      @client = client
    end

    def call
      imported = 0
      skipped = 0

      @client.matches.each do |payload|
        import_match(payload) ? imported += 1 : skipped += 1
      end

      Result.new(matches: imported, skipped:)
    end

    private

    def import_match(payload)
      home_team = find_team(payload.dig("homeTeam", "tla"))
      away_team = find_team(payload.dig("awayTeam", "tla"))
      return false unless home_team && away_team

      external_id = "football-data:#{payload.fetch('id')}"
      starts_at = Time.iso8601(payload.fetch("utcDate"))
      match = Match.find_by_external_id(external_id) || matching_match(home_team, away_team, starts_at)
      match ||= Match.new(external_id:, home_team:, away_team:)

      assign_match(match, payload, starts_at)
      match.save!
      match.external_references.find_or_create_by!(source: "football-data", external_id:)
      true
    end

    def assign_match(match, payload, starts_at)
      status = status_for(payload.fetch("status"))
      current_status = match.status
      match.assign_attributes(
        home_team: find_team(payload.dig("homeTeam", "tla")),
        away_team: find_team(payload.dig("awayTeam", "tla")),
        starts_at:, data_source: match.data_source.presence || "football-data",
        stage: payload["stage"].to_s.downcase, matchday: payload["matchday"],
        source_payload: match.source_payload.merge("football_data" => payload)
      )
      if status_rank(status) >= status_rank(current_status)
        match.status = status
        assign_score(match, payload)
        match.assign_attributes(clock_running: false, clock_updated_at: Time.current) if status == "finished"
      end
    end

    def assign_score(match, payload)
      score = payload.dig("score", "fullTime") || payload.dig("score", "regularTime") || {}
      match.home_score = score["home"].to_i unless score["home"].nil?
      match.away_score = score["away"].to_i unless score["away"].nil?
      return unless payload["minute"]

      match.clock_seconds = payload["minute"].to_i * 60
      match.clock_running = match.live?
      match.clock_updated_at = Time.current if match.clock_running?
    end

    def find_team(code)
      Team.find_by(fifa_code: code.to_s.upcase) if code.present?
    end

    def matching_match(home_team, away_team, starts_at)
      Match.where(home_team:, away_team:, starts_at: (starts_at - 18.hours)..(starts_at + 18.hours)).first
    end

    def status_for(status)
      { "SCHEDULED" => "scheduled", "TIMED" => "scheduled", "IN_PLAY" => "live", "PAUSED" => "live",
        "FINISHED" => "finished", "POSTPONED" => "postponed", "SUSPENDED" => "postponed",
        "CANCELLED" => "cancelled" }.fetch(status, "scheduled")
    end

    def status_rank(status)
      { "scheduled" => 0, "postponed" => 1, "cancelled" => 1, "live" => 2, "finished" => 3 }.fetch(status, 0)
    end
  end
end

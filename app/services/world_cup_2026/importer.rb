module WorldCup2026
  class Importer
    Result = Data.define(:teams, :matches, :remote)

    def initialize(client: Client.new)
      @client = client
    end

    def call
      response = @client.fetch
      teams_by_provider_id = import_teams(response.teams)
      imported_matches = import_matches(response.games, teams_by_provider_id, authoritative: response.remote)
      Result.new(teams: teams_by_provider_id.size, matches: imported_matches, remote: response.remote)
    end

    private

    def import_teams(payloads)
      payloads.each_with_object({}) do |payload, teams|
        team = Team.find_or_initialize_by(fifa_code: payload.fetch("fifa_code"))
        team.assign_attributes(
          name: payload.fetch("name_en"), country: payload.fetch("name_en"),
          group_name: payload["groups"], external_id: payload.fetch("id"),
          data_source: "worldcup2026", iso2: payload["iso2"], flag_url: payload["flag"],
          source_payload: payload
        )
        team.save!
        teams[payload.fetch("id").to_s] = team
      end
    end

    def import_matches(payloads, teams_by_provider_id, authoritative:)
      payloads.count do |payload|
        home_team = teams_by_provider_id[payload["home_team_id"].to_s]
        away_team = teams_by_provider_id[payload["away_team_id"].to_s]
        next false unless home_team && away_team

        external_id = "worldcup2026:#{payload.fetch('id')}"
        starts_at = parse_date(payload.fetch("local_date"))
        match = Match.find_by(external_id:)
        duplicate = matching_match(home_team, away_team, starts_at, excluding: match)

        if match && duplicate
          match = MatchDeduplicator.new(canonical: match, duplicate:).call
        elsif match.nil? && duplicate
          duplicate.external_references.find_or_create_by!(source: duplicate.data_source.presence || "legacy",
                                                            external_id: duplicate.external_id)
          match = duplicate
          match.external_id = external_id
        else
          match ||= Match.new(external_id:)
        end

        match.assign_attributes(
          home_team:, away_team:, starts_at:,
          data_source: "worldcup2026", stage: payload["type"], matchday: payload["matchday"].to_i,
          venue_external_id: payload["stadium_id"], source_payload: payload,
          status: status_for(payload)
        )
        assign_score(match, payload) if authoritative || match.new_record? || finished?(payload)
        match.save!
        match.external_references.find_or_create_by!(source: "worldcup2026", external_id:)
        true
      end
    end

    def assign_score(match, payload)
      match.home_score = payload["home_score"].to_i
      match.away_score = payload["away_score"].to_i
      match.clock_seconds = clock_seconds(payload["time_elapsed"])
      match.clock_running = match.status == "live"
      match.clock_updated_at = Time.current if match.clock_running?
    end

    def status_for(payload)
      return "finished" if finished?(payload)
      return "scheduled" if payload["time_elapsed"].blank? || payload["time_elapsed"] == "notstarted"

      "live"
    end

    def finished?(payload)
      ActiveModel::Type::Boolean.new.cast(payload["finished"])
    end

    def clock_seconds(value)
      value.to_s.match?(/\A\d+\z/) ? value.to_i * 60 : 0
    end

    def parse_date(value)
      Time.zone.strptime(value, "%m/%d/%Y %H:%M")
    end

    def matching_match(home_team, away_team, starts_at, excluding:)
      Match.where(home_team:, away_team:, starts_at: (starts_at - 18.hours)..(starts_at + 18.hours))
        .where.not(id: excluding&.id).first
    end
  end
end

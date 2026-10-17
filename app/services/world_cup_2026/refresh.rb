module WorldCup2026
  class Refresh
    def call
      teams = Importer.new.call
      details = { "teams" => { "count" => teams.teams, "source" => teams.remote ? "api" : "snapshot" } }

      if FootballData::Client.new.configured?
        begin
          result = FootballData::Importer.new.call
          details["football_data"] = { "matches" => result.matches }
        rescue FootballData::Client::Error => error
          Rails.logger.warn(event: "competition.football_data_unavailable", error: error.message)
          details["football_data"] = { "warning" => "O provedor secundário está indisponível." }
        end
      end

      details["espn"] = refresh_matches
      details
    end

    private

    def refresh_matches
      result = Espn::Importer.new(tournament: true, broadcast: false).call
      { "matches" => result.matches, "skipped" => result.skipped, "source" => "api" }
    rescue Espn::Client::Error => error
      Rails.logger.warn(event: "competition.espn_fallback", error: error.message)
      result = Espn::Importer.new(client: Espn::SnapshotClient.new, tournament: true, broadcast: false).call
      { "matches" => result.matches, "skipped" => result.skipped, "source" => "snapshot" }
    end
  end
end

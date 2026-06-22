module Espn
  class Importer
    Result = Data.define(:matches, :skipped)
    STATISTICS = {
      "totalShots" => "shots", "shotsOnTarget" => "shots_on_goal", "possessionPct" => "possession",
      "foulsCommitted" => "fouls", "wonCorners" => "corners", "offsides" => "offsides",
      "totalPasses" => "passes", "passPct" => "pass_accuracy"
    }.freeze

    def initialize(client: Client.new, date: Date.current)
      @client = client
      @date = date
    end

    def call
      imported = 0
      skipped = 0
      client.events(dates: [ date - 1.day, date ]).each do |payload|
        import_match(payload) ? imported += 1 : skipped += 1
      end
      Result.new(matches: imported, skipped:)
    end

    private

    attr_reader :client, :date

    def import_match(payload)
      competition = payload.fetch("competitions").first
      competitors = competition.fetch("competitors")
      home = competitors.find { |team| team.fetch("homeAway") == "home" }
      away = competitors.find { |team| team.fetch("homeAway") == "away" }
      home_team = Team.find_by(fifa_code: home.dig("team", "abbreviation"))
      away_team = Team.find_by(fifa_code: away.dig("team", "abbreviation"))
      return false unless home_team && away_team

      external_id = "espn-#{payload.fetch('id')}"
      starts_at = Time.zone.parse(payload.fetch("date"))
      match = Match.find_by_external_id(external_id) || matching_match(home_team, away_team, starts_at)
      return false unless match

      update_match(match, payload, competition, home, away)
      match.external_references.find_or_create_by!(source: "espn", external_id:)
      import_events(match, payload, competition, home, away)
      broadcast(match)
      true
    end

    def update_match(match, payload, competition, home, away)
      state = payload.dig("status", "type", "state")
      statistics = match.statistics.merge(statistics_for(home, away, competition.fetch("details", [])))
      attributes = {
        status: { "pre" => "scheduled", "in" => "live", "post" => "finished" }.fetch(state, match.status),
        home_score: home.fetch("score", match.home_score).to_i,
        away_score: away.fetch("score", match.away_score).to_i,
        clock_seconds: payload.dig("status", "clock").to_i,
        clock_running: state == "in", clock_updated_at: Time.current,
        statistics:,
        source_payload: match.source_payload.merge("espn" => payload)
      }
      match.update!(attributes)
    end

    def statistics_for(home, away, details)
      stats = STATISTICS.each_with_object({}) do |(provider_key, local_key), result|
        home_value = stat_value(home, provider_key)
        away_value = stat_value(away, provider_key)
        next if home_value.nil? && away_value.nil?

        result[local_key] = { "home" => cast(home_value), "away" => cast(away_value) }
      end
      stats["yellow_cards"] = card_counts(home, away, details, "yellowCard")
      stats["red_cards"] = card_counts(home, away, details, "redCard")
      stats
    end

    def stat_value(competitor, name)
      competitor.fetch("statistics", []).find { |stat| stat["name"] == name }&.fetch("displayValue", nil)
    end

    def cast(value)
      return nil if value.nil?

      value.to_s.include?(".") ? value.to_f : value.to_i
    end

    def card_counts(home, away, details, key)
      { "home" => details.count { |item| item[key] && item.dig("team", "id").to_s == home["id"].to_s },
        "away" => details.count { |item| item[key] && item.dig("team", "id").to_s == away["id"].to_s } }
    end

    def matching_match(home_team, away_team, starts_at)
      Match.where(home_team:, away_team:, starts_at: (starts_at - 18.hours)..(starts_at + 18.hours)).first
    end

    def import_events(match, payload, competition, home, away)
      teams = { home["id"].to_s => match.home_team, away["id"].to_s => match.away_team }
      competition.fetch("details", []).each do |detail|
        kind = event_kind(detail)
        team = teams[detail.dig("team", "id").to_s]
        next unless kind && team

        event = MatchEvent.find_or_initialize_by(external_id: event_external_id(payload, detail, kind))
        next if event.persisted?

        clock = detail.dig("clock", "value").to_i
        athlete = detail.fetch("athletesInvolved", []).first
        event.assign_attributes(
          match:, team:, kind:, occurred_at: match.starts_at + clock.seconds,
          payload: detail.merge("provider" => "espn", "minute" => clock / 60, "player" => athlete&.fetch("displayName", nil))
        )
        event.save!
        MatchEventBroadcaster.new(event).call
      end
    end

    def event_kind(detail)
      return "goal" if detail["scoringPlay"]
      return "red_card" if detail["redCard"]
      "yellow_card" if detail["yellowCard"]
    end

    def event_external_id(payload, detail, kind)
      athlete_id = detail.fetch("athletesInvolved", []).first&.fetch("id", nil)
      [ "espn", payload.fetch("id"), kind, detail.dig("team", "id"), detail.dig("clock", "value"), athlete_id ].compact.join(":")
    end

    def broadcast(match)
      Turbo::StreamsChannel.broadcast_replace_to(
        "match_#{match.id}", target: "match-live-panel", partial: "matches/live_panel", locals: { match: }
      )
    end
  end
end

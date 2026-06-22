require "test_helper"

class WorldCup2026::ImporterTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:response) do
    def fetch = response
  end

  test "imports teams and historical match data idempotently" do
    teams = [
      { "id" => "1", "name_en" => "Mexico", "fifa_code" => "MEX", "iso2" => "MX", "groups" => "A" },
      { "id" => "2", "name_en" => "South Africa", "fifa_code" => "RSA", "iso2" => "ZA", "groups" => "A" }
    ]
    games = [
      {
        "id" => "1", "home_team_id" => "1", "away_team_id" => "2", "local_date" => "06/11/2026 13:00",
        "home_score" => "2", "away_score" => "1", "finished" => "TRUE", "time_elapsed" => "90",
        "type" => "group", "group" => "A", "matchday" => "1", "stadium_id" => "1"
      }
    ]
    response = WorldCup2026::Client::Response.new(teams:, games:, remote: true)
    importer = WorldCup2026::Importer.new(client: FakeClient.new(response))

    2.times { importer.call }

    match = Match.find_by!(external_id: "worldcup2026:1")
    assert_equal 2, Team.where(data_source: "worldcup2026").count
    assert_equal 1, Match.where(data_source: "worldcup2026").count
    assert_equal [ 2, 1 ], [ match.home_score, match.away_score ]
    assert_equal "finished", match.status
    assert_equal 5_400, match.clock_seconds
  end

  test "does not replace a newer score with zeroed fallback data" do
    teams = [
      { "id" => "1", "name_en" => "Mexico", "fifa_code" => "MEX", "groups" => "A" },
      { "id" => "2", "name_en" => "South Africa", "fifa_code" => "RSA", "groups" => "A" }
    ]
    game = { "id" => "1", "home_team_id" => "1", "away_team_id" => "2", "local_date" => "06/11/2026 13:00",
             "home_score" => "0", "away_score" => "0", "finished" => "FALSE", "time_elapsed" => "notstarted" }
    remote = WorldCup2026::Client::Response.new(teams:, games: [ game.merge("home_score" => "3") ], remote: true)
    fallback = WorldCup2026::Client::Response.new(teams:, games: [ game ], remote: false)

    WorldCup2026::Importer.new(client: FakeClient.new(remote)).call
    WorldCup2026::Importer.new(client: FakeClient.new(fallback)).call

    assert_equal 3, Match.find_by!(external_id: "worldcup2026:1").home_score
  end

  test "merges the same fixture imported with a different timezone and provider id" do
    mexico = Team.create!(fifa_code: "MEX", name: "México", country: "México")
    south_africa = Team.create!(fifa_code: "RSA", name: "África do Sul", country: "África do Sul")
    legacy = Match.create!(external_id: "espn-123", home_team: mexico, away_team: south_africa,
                           starts_at: Time.zone.parse("2026-06-11 20:00"), statistics: { shots: { home: 4, away: 2 } })
    event = MatchEvent.create!(match: legacy, team: mexico, kind: "goal", external_id: "goal-1", occurred_at: Time.current)
    teams = [
      { "id" => "1", "name_en" => "Mexico", "fifa_code" => "MEX", "groups" => "A" },
      { "id" => "2", "name_en" => "South Africa", "fifa_code" => "RSA", "groups" => "A" }
    ]
    game = { "id" => "1", "home_team_id" => "1", "away_team_id" => "2", "local_date" => "06/11/2026 13:00",
             "home_score" => "1", "away_score" => "0", "finished" => "FALSE", "time_elapsed" => "20" }
    response = WorldCup2026::Client::Response.new(teams:, games: [ game ], remote: true)

    WorldCup2026::Importer.new(client: FakeClient.new(response)).call

    canonical = Match.find_by_external_id!("worldcup2026:1")
    assert_equal canonical, Match.find_by_external_id!("espn-123")
    assert_equal canonical, event.reload.match
    assert_equal 1, Match.where(home_team: mexico, away_team: south_africa).count
    assert_equal 4, canonical.stat(:shots, :home)
  end
end

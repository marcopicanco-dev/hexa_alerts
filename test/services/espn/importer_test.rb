require "test_helper"

class Espn::ImporterTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  FakeClient = Struct.new(:payloads) do
    def events(dates:) = payloads
  end

  test "imports detailed statistics without creating a duplicate match" do
    home_team = Team.create!(fifa_code: "NZL", name: "New Zealand", country: "New Zealand")
    away_team = Team.create!(fifa_code: "EGY", name: "Egypt", country: "Egypt")
    match = Match.create!(external_id: "worldcup2026:38", home_team:, away_team:,
                          starts_at: Time.iso8601("2026-06-22T01:00:00Z"))
    payload = {
      "id" => "760452", "date" => "2026-06-22T01:00Z",
      "status" => { "clock" => 3_480, "type" => { "state" => "in" } },
      "competitions" => [ { "details" => [ { "yellowCard" => true, "redCard" => false, "scoringPlay" => false,
                                              "clock" => { "value" => 1_200 }, "team" => { "id" => "2620" },
                                              "athletesInvolved" => [ { "id" => "9", "displayName" => "Jogador" } ] } ],
                            "competitors" => [
                              competitor("2666", "home", "NZL", "1", "8", "4", "11", "2", "39.4"),
                              competitor("2620", "away", "EGY", "0", "13", "2", "3", "2", "60.6")
                            ] } ]
    }

    result = Espn::Importer.new(client: FakeClient.new([ payload ]), date: Date.new(2026, 6, 22)).call

    assert_equal 1, result.matches
    assert_equal 1, Match.where(home_team:, away_team:).count
    assert_equal match, Match.find_by_external_id!("espn-760452")
    assert_equal 8, match.reload.stat(:shots, :home)
    assert_equal 2, match.stat(:shots_on_goal, :away)
    assert_equal 11, match.stat(:fouls, :home)
    assert_equal 2, match.stat(:corners, :away)
    assert_equal 1, match.stat(:yellow_cards, :away)
    assert_equal 3_480, match.clock_seconds
    assert_equal "yellow_card", match.match_events.find_by!(team: away_team).kind

    assert_no_difference("MatchEvent.count") do
      Espn::Importer.new(client: FakeClient.new([ payload ]), date: Date.new(2026, 6, 22)).call
    end
  end

  private

  def competitor(id, side, code, score, shots, on_target, fouls, corners, possession)
    stats = { "totalShots" => shots, "shotsOnTarget" => on_target, "foulsCommitted" => fouls,
              "wonCorners" => corners, "possessionPct" => possession }
    { "id" => id, "homeAway" => side, "score" => score, "team" => { "abbreviation" => code },
      "statistics" => stats.map { |name, display_value| { "name" => name, "displayValue" => display_value } } }
  end
end

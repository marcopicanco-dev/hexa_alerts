require "test_helper"
require "minitest/mock"

class WorldCup2026::RefreshTest < ActiveSupport::TestCase
  test "falls back to a complete archive when the ESPN API is unavailable" do
    unavailable = Object.new
    def unavailable.tournament_events = raise Espn::Client::Error, "API unavailable"

    WorldCup2026::Client.stub(:new, WorldCup2026::SnapshotClient.new) do
      Espn::Client.stub(:new, unavailable) do
        result = WorldCup2026::Refresh.new.call

        assert_equal "snapshot", result.dig("espn", "source")
        assert_equal 104, result.dig("espn", "matches")
        assert_equal 0, result.dig("espn", "skipped")
        assert_equal 48, Team.count
        assert_equal 104, Match.count
        assert_equal 104, Match.where(status: "finished").count
        final = Match.find_by!(stage: "final")
        assert_equal "ESP", final.home_team.fifa_code
        assert_equal [ 1, 0 ], [ final.home_score, final.away_score ]

        assert_no_difference([ "Match.count", "MatchEvent.count" ]) { WorldCup2026::Refresh.new.call }
        assert_equal 104, Match.where(status: "finished").count
      end
    end
  end
end

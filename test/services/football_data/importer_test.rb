require "test_helper"

class FootballData::ImporterTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:payloads) do
    def matches = payloads
  end

  setup do
    @home = Team.create!(fifa_code: "NZL", name: "New Zealand", country: "New Zealand")
    @away = Team.create!(fifa_code: "EGY", name: "Egypt", country: "Egypt")
    @payload = {
      "id" => 123, "utcDate" => "2026-06-22T01:00:00Z", "status" => "FINISHED", "stage" => "GROUP_STAGE",
      "matchday" => 2, "homeTeam" => { "tla" => "NZL" }, "awayTeam" => { "tla" => "EGY" },
      "score" => { "fullTime" => { "home" => 1, "away" => 0 } }
    }
  end

  test "reconciles a football-data match with an existing fixture" do
    existing = Match.create!(external_id: "worldcup2026:38", home_team: @home, away_team: @away,
                             starts_at: Time.zone.parse("2026-06-21 18:00"), status: "live")

    result = FootballData::Importer.new(client: FakeClient.new([ @payload ])).call

    assert_equal 1, result.matches
    assert_equal 1, Match.where(home_team: @home, away_team: @away).count
    assert_equal existing, Match.find_by_external_id!("football-data:123")
    assert_equal [ 1, 0 ], [ existing.reload.home_score, existing.away_score ]
    assert_equal "finished", existing.status
    assert_equal Time.iso8601("2026-06-22T01:00:00Z"), existing.starts_at
  end

  test "does not regress a finished match with older scheduled data" do
    existing = Match.create!(external_id: "worldcup2026:38", home_team: @home, away_team: @away,
                             starts_at: Time.current, status: "finished", home_score: 2)
    scheduled = @payload.merge("status" => "SCHEDULED", "score" => { "fullTime" => { "home" => 0, "away" => 0 } })

    FootballData::Importer.new(client: FakeClient.new([ scheduled ])).call

    assert_equal "finished", existing.reload.status
    assert_equal 2, existing.home_score
  end

  test "skips fixtures whose participants are not defined" do
    payload = @payload.merge("homeTeam" => { "tla" => nil })

    result = FootballData::Importer.new(client: FakeClient.new([ payload ])).call

    assert_equal 0, result.matches
    assert_equal 1, result.skipped
  end
end

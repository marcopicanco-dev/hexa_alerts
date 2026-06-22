require "test_helper"

class ProcessMatchEventJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  setup do
    @brazil = Team.create!(fifa_code: "BRA", name: "Brasil", country: "Brasil")
    @morocco = Team.create!(fifa_code: "MAR", name: "Marrocos", country: "Marrocos")
    @match = Match.create!(external_id: "match-001", home_team: @brazil, away_team: @morocco, starts_at: 1.day.from_now)
    @payload = {
      "event_id" => "evt-001", "match_id" => @match.external_id, "type" => "goal",
      "team_code" => @brazil.fifa_code, "occurred_at" => "2026-06-18T19:22:10Z", "player" => "Camisa 10"
    }
  end

  test "persists a goal and updates the score" do
    assert_difference("MatchEvent.count", 1) { ProcessMatchEventJob.perform_now(@payload) }

    assert_equal 1, @match.reload.home_score
    assert_equal "live", @match.status
    assert_equal "Camisa 10", MatchEvent.last.payload["player"]
  end

  test "is idempotent for duplicate provider event ids" do
    2.times { ProcessMatchEventJob.perform_now(@payload) }

    assert_equal 1, MatchEvent.where(external_id: "evt-001").count
    assert_equal 1, @match.reload.home_score
  end

  test "notifies only matching active subscriptions" do
    fan = Fan.create!(name: "Ana", email: "ana@example.com")
    AlertSubscription.create!(fan:, team: @brazil, event_kind: "goal")

    assert_broadcasts("fan_#{fan.id}_alerts", 2) do
      ProcessMatchEventJob.perform_now(@payload)
    end
  end

  test "updates the live snapshot from a provider event" do
    payload = @payload.merge(
      "event_id" => "snapshot-001", "type" => "match_update", "clock_seconds" => 537,
      "clock_running" => true,
      "statistics" => { "shots" => { "home" => 1, "away" => 1 } },
      "win_probabilities" => { "home" => 16, "draw" => 27, "away" => 57 }
    )

    ProcessMatchEventJob.perform_now(payload)

    @match.reload
    assert_equal 537, @match.clock_seconds
    assert_predicate @match, :clock_running?
    assert_equal 1, @match.stat(:shots, :home)
    assert_equal 57, @match.win_probability(:away)
  end

  test "accepts an external alias for the match" do
    @match.external_references.create!(source: "espn", external_id: "espn-alias")

    ProcessMatchEventJob.perform_now(@payload.merge("event_id" => "alias-event", "match_id" => "espn-alias"))

    assert_equal @match, MatchEvent.find_by!(external_id: "alias-event").match
  end
end

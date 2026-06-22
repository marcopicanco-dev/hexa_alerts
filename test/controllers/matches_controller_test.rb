require "test_helper"

class MatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    home = Team.create!(fifa_code: "NZL", name: "Nova Zelândia", country: "Nova Zelândia")
    away = Team.create!(fifa_code: "EGY", name: "Egito", country: "Egito")
    @match = Match.create!(
      external_id: "espn-760452", home_team: home, away_team: away, starts_at: Time.current,
      status: "live", clock_seconds: 537, clock_running: true, clock_updated_at: Time.current,
      statistics: { shots: { home: 1, away: 1 }, possession: { home: 49, away: 51 } },
      win_probabilities: { home: 16, draw: 27, away: 57 }
    )
  end

  test "shows the live clock and match statistics" do
    get match_path(@match)

    assert_response :success
    assert_select "[data-controller='match-clock'][data-match-clock-seconds-value='537']"
    assert_select "dt", text: "Chutes"
    assert_select "dd", text: "49%"
    assert_select "h1", text: "Nova Zelândia"
  end
end

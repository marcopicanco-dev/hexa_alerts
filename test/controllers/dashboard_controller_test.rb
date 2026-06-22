require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "renders an empty dashboard" do
    get root_path

    assert_response :success
    assert_select "h1", "HexaAlerts"
  end

  test "renders only events covered by the fan subscription" do
    brazil = Team.create!(fifa_code: "BRA", name: "Brasil", country: "Brasil")
    morocco = Team.create!(fifa_code: "MAR", name: "Marrocos", country: "Marrocos")
    match = Match.create!(external_id: "match-001", home_team: brazil, away_team: morocco, starts_at: 1.day.from_now)
    fan = Fan.create!(name: "Ana", email: "ana@example.com")
    AlertSubscription.create!(fan:, team: brazil, event_kind: "goal")
    MatchEvent.create!(match:, team: brazil, kind: "goal", external_id: "goal-1", occurred_at: Time.current)
    MatchEvent.create!(match:, team: brazil, kind: "yellow_card", external_id: "card-1", occurred_at: Time.current)

    get root_path(fan_id: fan.id)

    assert_response :success
    assert_select "article", count: 1
    assert_select "article", text: /Goal/
  end

  test "lists live matches first and exposes them in a modal" do
    brazil = Team.create!(fifa_code: "BRA", name: "Brasil", country: "Brasil")
    morocco = Team.create!(fifa_code: "MAR", name: "Marrocos", country: "Marrocos")
    scheduled = Match.create!(external_id: "scheduled", home_team: brazil, away_team: morocco,
                              starts_at: 1.hour.ago, status: "scheduled")
    live = Match.create!(external_id: "live", home_team: morocco, away_team: brazil,
                         starts_at: 1.hour.from_now, status: "live")

    get root_path

    assert_response :success
    assert_select "button", text: /1 jogo ao vivo/
    assert_select "[data-testid='matches-list'] .match-card:first-child[data-match-status='live'][href='#{match_path(live)}']"
    assert_select "[data-testid='matches-list'] .match-card:last-child[href='#{match_path(scheduled)}']"
    assert_select "[data-testid='live-matches-modal'] .match-card", count: 1
    assert_select "[data-testid='live-matches-modal'] .match-card[href='#{match_path(live)}']"
  end
end

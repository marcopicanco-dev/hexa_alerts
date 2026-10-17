require "application_system_test_case"
require "minitest/mock"

class DashboardTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    travel_to Time.zone.local(2026, 10, 17, 12)
    @spain = Team.create!(fifa_code: "ESP", name: "Spain", country: "Spain")
    argentina = Team.create!(fifa_code: "ARG", name: "Argentina", country: "Argentina")
    @final = Match.create!(external_id: "final", home_team: @spain, away_team: argentina,
      starts_at: Time.zone.local(2026, 7, 19, 19), stage: "final", status: "finished",
      home_score: 1, away_score: 0, statistics: { shots: { home: 20, away: 2 } })
    @group_match = Match.create!(external_id: "group", home_team: argentina, away_team: @spain,
      starts_at: Time.zone.local(2026, 6, 20, 19), stage: "group_stage", status: "finished")
    Fan.create!(name: "Ana", email: "ana@example.com")
    MatchEvent.create!(match: @final, team: @spain, kind: "goal", external_id: "final-goal",
      occurred_at: @final.starts_at + 106.minutes,
      payload: { player: "Ferran Torres", clock: { displayValue: "106'" } })
  end

  teardown do
    travel_back
    page.driver.browser.manage.window.resize_to(1400, 1100)
  end

  test "browses the final rankings, filters and match details" do
    visit root_path

    assert_text "COMPETIÇÃO ENCERRADA"
    within "[data-testid='final-standings']" do
      assert_selector "li", count: 5
      assert_text "Espanha"
      assert_text "Noruega"
    end
    within "[data-testid='top-scorers']" do
      assert_selector "li", count: 5
      assert_text "Kylian Mbappé"
    end
    assert_selector "[data-testid='matches-list'] .match-card", count: 1

    click_link "Grupos"
    assert_selector "[data-testid='matches-list'] .match-card[href='#{match_path(@group_match)}']"
    assert_no_selector "[data-testid='matches-list'] .match-card[href='#{match_path(@final)}']"

    click_link "Todos", exact: true
    assert_selector "[data-testid='matches-list'] .match-card", count: 2

    click_link "Mata-mata"
    find("[data-testid='matches-list'] .match-card[href='#{match_path(@final)}']").click

    assert_current_path match_path(@final)
    within "#match-live-panel" do
      assert_selector "h1", text: "Espanha"
      assert_text /encerrado/i
      assert_selector "dt", text: "Chutes", exact_text: true
      assert_selector "dd", text: "20", exact_text: true
    end
    assert_text "Ferran Torres"
    assert_text "106'"
    assert_no_text "Probabilidade de vitória ao vivo"
  end

  test "refreshes the dashboard when the background update finishes" do
    service = Object.new
    def service.call = { "espn" => { "matches" => 2, "source" => "api" } }

    WorldCup2026::Refresh.stub(:new, -> { service }) do
      visit root_path
      assert_selector "main > turbo-cable-stream-source[connected]", visible: :all
      click_button "Atualizar aplicação"

      assert_text "Atualização iniciada."
      assert_button "Atualizando…", disabled: true
      assert_enqueued_with(job: RefreshCompetitionJob)
      assert_selector "main > turbo-cable-stream-source[connected]", visible: :all

      perform_enqueued_jobs(only: RefreshCompetitionJob)

      assert_selector "[aria-live='polite']", text: "Última atualização:"
      assert_button "Atualizar aplicação", disabled: false
      assert_predicate CompetitionSync.last, :completed?
    end
  end

  test "creates and removes a personalized alert" do
    visit root_path

    select "Espanha", from: "alert_subscription_team_id"
    select "Gol", from: "alert_subscription_event_kind"
    click_button "Ativar alerta"

    assert_text "Alerta ativado."
    assert_selector "aside", text: "Espanha · Gol"
    assert_equal @spain, AlertSubscription.last.team

    find("button[aria-label='Remover alerta']").click

    assert_text "Alerta removido."
    assert_text "Você ainda não tem assinaturas."
    assert_empty AlertSubscription.all
  end

  test "shows the mobile dashboard without horizontal overflow" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit root_path

    assert_button "Atualizar aplicação"
    assert_text "COMPETIÇÃO ENCERRADA"
    assert_selector "[data-testid='final-standings'] li", count: 5
    assert_selector "[data-testid='top-scorers'] li", count: 5
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
  end
end

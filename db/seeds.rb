brazil = Team.find_or_create_by!(fifa_code: "BRA") { |team| team.assign_attributes(name: "Brasil", country: "Brasil", group_name: "C") }
morocco = Team.find_or_create_by!(fifa_code: "MAR") { |team| team.assign_attributes(name: "Marrocos", country: "Marrocos", group_name: "C") }

match = Match.find_or_create_by!(external_id: "match-001") do |game|
  game.assign_attributes(home_team: brazil, away_team: morocco, starts_at: Time.zone.parse("2026-06-13 19:00:00"))
end

fan = Fan.find_or_create_by!(email: "torcedor@example.com") { |record| record.name = "Torcedor Hexa" }
AlertSubscription.find_or_create_by!(fan:, team: brazil, event_kind: "goal")

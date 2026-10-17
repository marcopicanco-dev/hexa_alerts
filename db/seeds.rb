WorldCup2026::Importer.new(client: WorldCup2026::SnapshotClient.new).call
Espn::Importer.new(client: Espn::SnapshotClient.new, tournament: true, broadcast: false).call

brazil = Team.find_by!(fifa_code: "BRA")
fan = Fan.find_or_create_by!(email: "torcedor@example.com") { |record| record.name = "Torcedor Hexa" }
AlertSubscription.find_or_create_by!(fan:, team: brazil, event_kind: "goal")

puts "Acervo carregado: #{Team.count} seleções, #{Match.count} partidas e #{MatchEvent.count} lances."

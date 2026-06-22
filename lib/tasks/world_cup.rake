namespace :world_cup do
  desc "Synchronize teams, schedule and results from worldcup26.ir"
  task sync: :environment do
    result = WorldCup2026::Importer.new.call
    source = result.remote ? "API remota" : "dataset local de fallback"
    puts "Sincronização concluída via #{source}: #{result.teams} seleções, #{result.matches} partidas."
  end
end

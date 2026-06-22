namespace :espn do
  desc "Synchronize World Cup scores and detailed match statistics from ESPN"
  task sync: :environment do
    date = ENV.fetch("DATE", Date.current.iso8601)
    result = Espn::Importer.new(date: Date.iso8601(date)).call
    puts "ESPN: #{result.matches} partidas sincronizadas, #{result.skipped} ignoradas."
  end
end

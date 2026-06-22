namespace :football_data do
  desc "Synchronize World Cup matches from football-data.org"
  task sync: :environment do
    client = FootballData::Client.new
    abort "Configure FOOTBALL_DATA_API_TOKEN antes de sincronizar." unless client.configured?

    result = FootballData::Importer.new(client:).call
    puts "football-data.org: #{result.matches} partidas sincronizadas, #{result.skipped} ignoradas."
  end
end

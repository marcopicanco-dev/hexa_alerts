namespace :competition do
  desc "Refresh all World Cup teams and matches"
  task refresh: :environment do
    sync = CompetitionSync.create!
    RefreshCompetitionJob.perform_now(sync)
    puts "Atualização concluída: #{sync.reload.details.to_json}"
  end
end

class SyncWorldCupDataJob < ApplicationJob
  queue_as :default

  retry_on WorldCup2026::Client::Error, wait: :polynomially_longer, attempts: 5

  def perform
    result = WorldCup2026::Importer.new.call
    Rails.logger.info(event: "world_cup_2026.synced", teams: result.teams, matches: result.matches, remote: result.remote)
  end
end

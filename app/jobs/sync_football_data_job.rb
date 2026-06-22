class SyncFootballDataJob < ApplicationJob
  queue_as :default

  retry_on FootballData::Client::Error, wait: :polynomially_longer, attempts: 5

  def perform
    result = FootballData::Importer.new.call
    Rails.logger.info(event: "football_data.synced", matches: result.matches, skipped: result.skipped)
  end
end

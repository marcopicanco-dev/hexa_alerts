class SyncEspnDataJob < ApplicationJob
  queue_as :default

  retry_on Espn::Client::Error, wait: :polynomially_longer, attempts: 5

  def perform(date = Date.current.iso8601, recurring = true, schedule_token = nil)
    scheduler = Espn::SyncScheduler.new
    scheduler.clear_scheduled(schedule_token)
    token = scheduler.acquire
    return unless token

    begin
      result = Espn::Importer.new(date: Date.iso8601(date)).call
      Rails.logger.info(event: "espn.synced", matches: result.matches, skipped: result.skipped)
    ensure
      scheduler.release(token)
    end

    scheduler.schedule(date: Date.current.iso8601) if recurring
  end
end

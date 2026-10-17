class RefreshCompetitionJob < ApplicationJob
  queue_as :default

  def perform(sync)
    sync.with_lock do
      return unless sync.status == "queued"

      sync.update!(status: "running")
    end
    details = WorldCup2026::Refresh.new.call
    sync.update!(status: "completed", details:, finished_at: Time.current)
  rescue StandardError => error
    sync.update!(status: "failed", finished_at: Time.current,
      error_message: "A atualização não foi concluída. Os dados salvos continuam disponíveis.")
    raise error
  ensure
    Turbo::StreamsChannel.broadcast_refresh_to("competition_updates")
  end
end

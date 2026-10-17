class CompetitionSyncsController < ApplicationController
  def create
    sync = CompetitionSync.create!
    job = RefreshCompetitionJob.perform_later(sync)
    raise ActiveJob::EnqueueError, "Job was not enqueued" unless job

    redirect_to root_path(fan_id: params[:fan_id].presence), notice: "Atualização iniciada. Você pode continuar navegando.", status: :see_other
  rescue ActiveRecord::RecordNotUnique
    redirect_to root_path(fan_id: params[:fan_id].presence), notice: "Já existe uma atualização em andamento.", status: :see_other
  rescue RedisClient::Error, ActiveJob::EnqueueError => error
    Rails.logger.error(event: "competition.enqueue_failed", error: error.message)
    sync&.update!(status: "failed", finished_at: Time.current, error_message: "Não foi possível iniciar a atualização. Verifique se o Redis está disponível.")
    redirect_to root_path, alert: "Não foi possível iniciar a atualização. Tente novamente.", status: :see_other
  end
end

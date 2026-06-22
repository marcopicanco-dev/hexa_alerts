class AlertSubscriptionsController < ApplicationController
  def create
    subscription = AlertSubscription.new(subscription_params)
    subscription.save!
    redirect_to root_path(fan_id: subscription.fan_id), notice: "Alerta ativado."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to root_path(fan_id: subscription.fan_id), alert: error.record.errors.full_messages.to_sentence
  rescue ActiveRecord::RecordNotUnique
    redirect_to root_path(fan_id: subscription.fan_id), alert: "Esse alerta já está ativo."
  end

  def destroy
    subscription = AlertSubscription.find(params[:id])
    fan_id = subscription.fan_id
    subscription.destroy!
    redirect_to root_path(fan_id:), notice: "Alerta removido."
  end

  private

  def subscription_params
    params.require(:alert_subscription).permit(:fan_id, :team_id, :match_id, :event_kind).compact_blank
  end
end

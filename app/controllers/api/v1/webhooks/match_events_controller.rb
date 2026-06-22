module Api
  module V1
    module Webhooks
      class MatchEventsController < ApplicationController
        skip_forgery_protection

        REQUIRED_FIELDS = %w[event_id match_id type team_code occurred_at].freeze

        def create
          return render json: { error: "unauthorized" }, status: :unauthorized unless valid_token?

          payload = webhook_params.to_h
          missing = REQUIRED_FIELDS.select { |field| payload[field].blank? }
          return render json: { error: "missing fields", fields: missing }, status: :unprocessable_content if missing.any?
          return render json: { error: "unsupported event type" }, status: :unprocessable_content unless MatchEvent::KINDS.include?(payload["type"])
          return render json: { error: "invalid occurred_at" }, status: :unprocessable_content unless valid_timestamp?(payload["occurred_at"])

          ProcessMatchEventJob.perform_later(payload)
          render json: { status: "accepted" }, status: :accepted
        end

        private

        def webhook_params
          params.permit(
            :event_id, :match_id, :type, :team_code, :occurred_at, :player,
            :clock_seconds, :clock_running,
            statistics: {}, win_probabilities: {}
          )
        end

        def valid_token?
          supplied = request.headers["X-Webhook-Token"].to_s
          expected = ENV.fetch("WEBHOOK_TOKEN") { Rails.env.production? ? "" : "dev-token" }
          supplied.bytesize == expected.bytesize && expected.present? && ActiveSupport::SecurityUtils.secure_compare(supplied, expected)
        end

        def valid_timestamp?(value)
          Time.iso8601(value)
          true
        rescue ArgumentError
          false
        end
      end
    end
  end
end

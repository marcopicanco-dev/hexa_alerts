require "test_helper"

class Api::V1::Webhooks::MatchEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @payload = {
      event_id: "evt-001", match_id: "match-001", type: "goal", team_code: "BRA",
      occurred_at: "2026-06-18T19:22:10Z", player: "Camisa 10"
    }
    @headers = { "X-Webhook-Token" => "dev-token" }
  end

  test "accepts a valid webhook and enqueues processing" do
    assert_enqueued_with(job: ProcessMatchEventJob) do
      post api_v1_webhooks_match_events_path, params: @payload, as: :json, headers: @headers
    end

    assert_response :accepted
    assert_equal({ "status" => "accepted" }, response.parsed_body)
  end

  test "rejects an invalid token" do
    assert_no_enqueued_jobs do
      post api_v1_webhooks_match_events_path, params: @payload, as: :json, headers: { "X-Webhook-Token" => "wrong" }
    end

    assert_response :unauthorized
  end

  test "rejects malformed payloads" do
    post api_v1_webhooks_match_events_path, params: @payload.except(:event_id), as: :json, headers: @headers

    assert_response :unprocessable_content
    assert_includes response.parsed_body["fields"], "event_id"
  end
end

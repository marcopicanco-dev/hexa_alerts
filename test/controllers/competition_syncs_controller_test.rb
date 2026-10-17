require "test_helper"

class CompetitionSyncsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "queues a full refresh and returns to the dashboard" do
    assert_enqueued_with(job: RefreshCompetitionJob) do
      assert_difference("CompetitionSync.count", 1) { post competition_syncs_path }
    end

    assert_redirected_to root_path
    assert_equal "queued", CompetitionSync.last.status
    follow_redirect!
    assert_select "[data-testid='refresh-competition'][disabled]"
  end

  test "does not enqueue duplicate updates" do
    CompetitionSync.create!(status: "running")

    assert_no_enqueued_jobs do
      assert_no_difference("CompetitionSync.count") { post competition_syncs_path }
    end

    assert_redirected_to root_path
    assert_match "Já existe", flash[:notice]
  end
end

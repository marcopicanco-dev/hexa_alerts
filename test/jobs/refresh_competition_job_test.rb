require "test_helper"
require "minitest/mock"

class RefreshCompetitionJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  test "records a completed refresh and notifies browsers" do
    sync = CompetitionSync.create!
    service = Object.new
    def service.call = { "espn" => { "matches" => 104, "source" => "api" } }

    WorldCup2026::Refresh.stub(:new, -> { service }) do
      assert_broadcasts("competition_updates", 1) { RefreshCompetitionJob.perform_now(sync) }
    end

    assert_predicate sync.reload, :completed?
    assert_not_nil sync.finished_at
    assert_equal 104, sync.details.dig("espn", "matches")
  end

  test "records failures and releases the active update" do
    sync = CompetitionSync.create!
    service = Object.new
    def service.call = raise RuntimeError, "Unexpected import failure"

    WorldCup2026::Refresh.stub(:new, -> { service }) do
      assert_raises(RuntimeError) { RefreshCompetitionJob.perform_now(sync) }
    end

    assert_equal "failed", sync.reload.status
    assert_not_nil sync.finished_at
    assert_not sync.active?
    assert CompetitionSync.create!.persisted?
  end
end

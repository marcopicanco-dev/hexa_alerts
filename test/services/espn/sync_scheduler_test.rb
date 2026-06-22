require "test_helper"

class Espn::SyncSchedulerTest < ActiveSupport::TestCase
  class FakeRedis
    def initialize = @values = {}

    def set(key, value, nx:, ex:)
      return false if nx && @values.key?(key)

      @values[key] = value
      "OK"
    end

    def get(key) = @values[key]
    def del(key) = @values.delete(key)
  end

  class FakeJob
    class << self
      attr_reader :wait, :arguments

      def set(wait:)
        @wait = wait
        self
      end

      def perform_later(*arguments)
        @arguments = arguments
      end
    end
  end

  test "schedules only one pending synchronization" do
    scheduler = Espn::SyncScheduler.new(redis: FakeRedis.new, job_class: FakeJob)

    assert scheduler.schedule(date: "2026-06-22", wait: 30)
    assert_not scheduler.schedule(date: "2026-06-22", wait: 30)
    assert_equal 30, FakeJob.wait
    assert_equal [ "2026-06-22", true ], FakeJob.arguments.first(2)
    assert_predicate FakeJob.arguments.last, :present?
  end

  test "uses a short interval while a match is live" do
    home = Team.create!(fifa_code: "NZL", name: "New Zealand", country: "New Zealand")
    away = Team.create!(fifa_code: "EGY", name: "Egypt", country: "Egypt")
    Match.create!(external_id: "live", home_team: home, away_team: away, starts_at: Time.current, status: "live")
    scheduler = Espn::SyncScheduler.new(redis: FakeRedis.new, job_class: FakeJob)

    assert_equal 30, scheduler.next_interval
  end
end

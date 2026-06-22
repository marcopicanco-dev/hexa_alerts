require "securerandom"

module Espn
  class SyncScheduler
    def initialize(redis: Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/2")),
                   job_class: SyncEspnDataJob)
      @redis = redis
      @job_class = job_class
    end

    def acquire
      token = SecureRandom.uuid
      redis.set(running_key, token, nx: true, ex: 60) ? token : nil
    end

    def release(token)
      redis.del(running_key) if redis.get(running_key) == token
    end

    def clear_scheduled(token)
      redis.del(scheduled_key) if token.present? && redis.get(scheduled_key) == token
    end

    def schedule(date:, wait: next_interval)
      token = SecureRandom.uuid
      return false unless redis.set(scheduled_key, token, nx: true, ex: wait + 120)

      job_class.set(wait:).perform_later(date, true, token)
      true
    rescue StandardError
      redis.del(scheduled_key) if redis.get(scheduled_key) == token
      raise
    end

    def next_interval
      Match.where(status: "live").exists? ? live_interval : idle_interval
    end

    private

    attr_reader :redis, :job_class

    def live_interval
      ENV.fetch("ESPN_LIVE_SYNC_INTERVAL", 30).to_i.clamp(15, 300)
    end

    def idle_interval
      ENV.fetch("ESPN_IDLE_SYNC_INTERVAL", 300).to_i.clamp(60, 3_600)
    end

    def running_key = "hexa_alerts:#{Rails.env}:espn_sync:running"
    def scheduled_key = "hexa_alerts:#{Rails.env}:espn_sync:scheduled"
  end
end

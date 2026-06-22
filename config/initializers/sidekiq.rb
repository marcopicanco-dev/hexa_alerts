redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/2")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  config.on(:startup) { SyncEspnDataJob.perform_later(Date.current.iso8601, true) }
end
Sidekiq.configure_client { |config| config.redis = { url: redis_url } }

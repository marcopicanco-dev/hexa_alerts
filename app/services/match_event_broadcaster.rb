class MatchEventBroadcaster
  def initialize(match_event)
    @match_event = match_event
  end

  def call
    AlertSubscription.active.for_event(match_event).includes(:fan).map(&:fan).uniq.each do |fan|
      stream = "fan_#{fan.id}_alerts"
      Turbo::StreamsChannel.broadcast_remove_to(stream, target: "alerts-empty")
      Turbo::StreamsChannel.broadcast_prepend_to(
        stream,
        target: "alerts",
        partial: "match_events/alert",
        locals: { match_event: }
      )
    end
  end

  private

  attr_reader :match_event
end

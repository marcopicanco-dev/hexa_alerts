class MatchDeduplicator
  def initialize(canonical:, duplicate:)
    @canonical = canonical
    @duplicate = duplicate
  end

  def call
    return canonical if canonical == duplicate

    Match.transaction do
      preserve_external_reference
      merge_snapshot
      move_events
      move_subscriptions
      move_external_references
      duplicate.destroy!
    end

    canonical.reload
  end

  private

  attr_reader :canonical, :duplicate

  def preserve_external_reference
    source = duplicate.data_source.presence || duplicate.external_id.to_s.split(/[-:]/).first.presence || "legacy"
    canonical.external_references.find_or_create_by!(source:, external_id: duplicate.external_id)
  end

  def merge_snapshot
    attributes = {}
    attributes[:statistics] = duplicate.statistics if canonical.statistics.blank? && duplicate.statistics.present?
    attributes[:win_probabilities] = duplicate.win_probabilities if canonical.win_probabilities.blank? && duplicate.win_probabilities.present?
    if canonical.clock_seconds.zero? && duplicate.clock_seconds.positive?
      attributes.merge!(clock_seconds: duplicate.clock_seconds, clock_running: duplicate.clock_running,
                        clock_updated_at: duplicate.clock_updated_at)
    end
    canonical.update!(attributes) if attributes.any?
  end

  def move_events
    duplicate.match_events.update_all(match_id: canonical.id) # rubocop:disable Rails/SkipsModelValidations
  end

  def move_subscriptions
    duplicate.alert_subscriptions.find_each do |subscription|
      existing = canonical.alert_subscriptions.find_by(fan_id: subscription.fan_id, team_id: subscription.team_id,
                                                        event_kind: subscription.event_kind)
      existing ? subscription.destroy! : subscription.update!(match: canonical)
    end
  end

  def move_external_references
    duplicate.external_references.where.not(external_id: canonical.external_references.select(:external_id))
      .update_all(match_id: canonical.id) # rubocop:disable Rails/SkipsModelValidations
  end
end

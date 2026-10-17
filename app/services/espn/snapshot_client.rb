module Espn
  class SnapshotClient
    def tournament_events
      JSON.parse(Rails.root.join("db/data/worldcup2026/espn_matches.json").read).fetch("events")
    end
  end
end

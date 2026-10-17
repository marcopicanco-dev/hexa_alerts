module WorldCup2026
  class SnapshotClient
    def fetch
      Client::Response.new(
        teams: JSON.parse(Rails.root.join("db/data/worldcup2026/teams.json").read),
        games: JSON.parse(Rails.root.join("db/data/worldcup2026/games.json").read),
        remote: false
      )
    end
  end
end

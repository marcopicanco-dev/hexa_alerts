module WorldCup2026
  class Summary
    STARTS_ON = Date.new(2026, 6, 11)
    ENDS_ON = Date.new(2026, 7, 19)

    def initialize
      @data = JSON.parse(Rails.root.join("db/data/worldcup2026/summary.json").read)
    end

    def finished? = Date.current > ENDS_ON
    def standings = @data.fetch("standings").first(5)
    def scorers = @data.fetch("scorers").first(5)
    def sources = @data.fetch("sources")
    def verified_on = Date.iso8601(@data.fetch("verified_on"))
  end
end

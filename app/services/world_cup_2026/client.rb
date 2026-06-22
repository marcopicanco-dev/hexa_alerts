require "net/http"

module WorldCup2026
  class Client
    Response = Data.define(:teams, :games, :remote)
    Error = Class.new(StandardError)

    def initialize(base_url: ENV.fetch("WORLD_CUP_API_URL", "https://worldcup26.ir"))
      @base_uri = URI(base_url)
    end

    def fetch
      Response.new(
        teams: get("/get/teams").fetch("teams"),
        games: get("/get/games").fetch("games"),
        remote: true
      )
    rescue Error, JSON::ParserError, KeyError, SystemCallError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError => error
      Rails.logger.warn(event: "world_cup_2026.fallback", error: error.message)
      Response.new(teams: fallback("teams"), games: fallback("games"), remote: false)
    end

    private

    def get(path)
      uri = @base_uri + path
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 15) do |http|
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "application/json"
        request["User-Agent"] = "HexaAlerts/1.0"
        http.request(request)
      end
      raise Error, "#{uri} returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def fallback(name)
      JSON.parse(Rails.root.join("db/data/worldcup2026/#{name}.json").read)
    end
  end
end

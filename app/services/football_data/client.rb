require "net/http"

module FootballData
  class Client
    Error = Class.new(StandardError)

    attr_reader :token

    def initialize(token: ENV["FOOTBALL_DATA_API_TOKEN"],
                   base_url: ENV.fetch("FOOTBALL_DATA_API_URL", "https://api.football-data.org/v4"))
      @token = token
      @base_uri = URI(base_url.end_with?("/") ? base_url : "#{base_url}/")
    end

    def configured? = token.present?

    def matches(season: 2026, competition: "WC")
      raise Error, "FOOTBALL_DATA_API_TOKEN is not configured" unless configured?

      get("competitions/#{competition}/matches?season=#{season}").fetch("matches")
    end

    private

    def get(path)
      uri = @base_uri + path
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 15) do |http|
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "application/json"
        request["X-Auth-Token"] = token
        request["User-Agent"] = "HexaAlerts/1.0"
        http.request(request)
      end
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

      message = JSON.parse(response.body).fetch("message", response.message)
      raise Error, "football-data.org returned HTTP #{response.code}: #{message}"
    rescue JSON::ParserError
      raise Error, "football-data.org returned an invalid JSON response"
    rescue SystemCallError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError => error
      raise Error, "football-data.org request failed: #{error.message}"
    end
  end
end

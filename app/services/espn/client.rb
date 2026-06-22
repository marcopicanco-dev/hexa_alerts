require "net/http"

module Espn
  class Client
    Error = Class.new(StandardError)

    def initialize(base_url: ENV.fetch("ESPN_SCOREBOARD_URL", "https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard"))
      @base_uri = URI(base_url)
    end

    def events(dates:)
      dates.flat_map { |date| get(date).fetch("events") }.uniq { |event| event.fetch("id") }
    end

    private

    def get(date)
      uri = @base_uri.dup
      uri.query = URI.encode_www_form(dates: date.strftime("%Y%m%d"))
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) do |http|
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "application/json"
        request["User-Agent"] = "HexaAlerts/1.0"
        http.request(request)
      end
      raise Error, "ESPN returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Error, "ESPN returned an invalid JSON response"
    rescue SystemCallError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError => error
      raise Error, "ESPN request failed: #{error.message}"
    end
  end
end

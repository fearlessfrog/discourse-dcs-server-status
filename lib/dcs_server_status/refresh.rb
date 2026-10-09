# frozen_string_literal: true

require "cgi"
require "ipaddr"

module ::DcsServerStatus
  class Refresh
    def self.call(force: false)
      DistributedMutex.synchronize("dcs-server-status:refresh", validity: 60) do
        config = Configuration.new
        return unless config.ready?

        previous = Store.snapshot(config)
        now = Time.now.to_i
        if !force && previous["last_attempt_at"] &&
             now - previous["last_attempt_at"] < config.interval
          return
        end

        client = EdClient.new(config, cookies: Store.session(config))
        begin
          servers = client.servers
          matches =
            servers.select do |server|
              text(server["NAME"], 512) == config.server_name
            end
          if matches.length > 1
            raise EdClient::Error.new("ambiguous_server_name")
          end
          server = matches.first && normalize(matches.first)

          return if Configuration.new.identity != config.identity
          Store.write_session(client.cookies, config)
          Store.write_snapshot(
            {
              "status" => server ? "online" : "not_listed",
              "server" => server,
              "last_success_at" => Time.now.to_i,
              "last_attempt_at" => now
            },
            config
          )
        rescue EdClient::Error => error
          return if Configuration.new.identity != config.identity
          if %w[authentication_failed interactive_login_required].include?(
               error.code
             )
            Store.clear_session!
          end
          if !previous["last_success_at"] ||
               now - previous["last_success_at"] >= Store::RETENTION
            previous = { "status" => "unknown" }
          end
          Store.write_snapshot(
            previous.merge("last_attempt_at" => now, "error" => error.code),
            config
          )
          Rails.logger.warn(
            "[discourse-dcs-server-status] Refresh failed: #{error.code}"
          )
        end
      end
    end

    def self.normalize(server)
      address = text(server["IP_ADDRESS"], 64)
      IPAddr.new(address)
      port = number(server["PORT"])
      unless port.between?(1, 65_535)
        raise EdClient::Error.new("invalid_response")
      end

      {
        "name" => text(server["NAME"], 512),
        "ip_address" => address,
        "port" => port,
        "mission" => text(server["MISSION_NAME"], 2048),
        "mission_time_seconds" => number(server["MISSION_TIME"]),
        "players" => number(server["PLAYERS"]),
        "players_max" => number(server["PLAYERS_MAX"])
      }
    rescue IPAddr::InvalidAddressError
      raise EdClient::Error.new("invalid_response")
    end

    def self.number(value)
      unless value.to_s.match?(/\A\d{1,12}\z/)
        raise EdClient::Error.new("invalid_response")
      end
      value.to_i
    end

    def self.text(value, limit)
      CGI.unescapeHTML(value.to_s).truncate(limit, omission: "")
    end
    private_class_method :normalize, :number, :text
  end
end

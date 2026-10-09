# frozen_string_literal: true

module ::DcsServerStatus
  class Store
    RETENTION = 24.hours.to_i
    STATUS_KEY = "dcs-server-status:snapshot"
    SESSION_KEY = "dcs-server-status:session"

    def self.snapshot(config = Configuration.new)
      data = read(STATUS_KEY)
      data && data["identity"] == config.identity ? data : {}
    end

    def self.write_snapshot(data, config)
      Discourse.redis.setex(
        STATUS_KEY,
        RETENTION,
        data.merge("identity" => config.identity).to_json
      )
    end

    def self.session(config)
      data = read(SESSION_KEY)
      if data && data["identity"] == config.credential_identity
        data["cookies"]
      else
        []
      end
    end

    def self.write_session(cookies, config)
      Discourse.redis.setex(
        SESSION_KEY,
        RETENTION,
        { identity: config.credential_identity, cookies: cookies }.to_json
      )
    end

    def self.clear_session!
      Discourse.redis.del(SESSION_KEY)
    end

    def self.clear_status!
      Discourse.redis.del(STATUS_KEY)
    end

    def self.public_status(config = Configuration.new)
      data = snapshot(config)
      success_at = data["last_success_at"]
      expired = success_at.nil? || Time.now.to_i - success_at >= RETENTION

      {
        status: expired ? "unknown" : data.fetch("status", "unknown"),
        stale:
          !expired &&
            (
              data["error"].present? ||
                Time.now.to_i - success_at > config.interval * 2
            ),
        last_success_at: success_at && Time.at(success_at).utc.iso8601,
        server: expired ? nil : data["server"],
        server_name: config.server_name
      }
    end

    def self.diagnostics
      config = Configuration.new
      data = snapshot(config)

      public_status(config).merge(
        configured: config.ready?,
        last_attempt_at:
          data["last_attempt_at"] &&
            Time.at(data["last_attempt_at"]).utc.iso8601,
        error: data["error"],
        interval_minutes: config.interval / 60
      )
    end

    def self.read(key)
      value = Discourse.redis.get(key)
      value && JSON.parse(value)
    end
    private_class_method :read
  end
end

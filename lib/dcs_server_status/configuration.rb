# frozen_string_literal: true

require "digest"

module ::DcsServerStatus
  class Configuration
    attr_reader :username, :password, :server_name, :interval

    def initialize
      @enabled = SiteSetting.dcs_server_status_enabled
      @username = SiteSetting.dcs_server_status_username.strip
      @password = SiteSetting.dcs_server_status_password
      @server_name = SiteSetting.dcs_server_status_server_name.strip
      @interval =
        SiteSetting.dcs_server_status_poll_interval_minutes.minutes.to_i
    end

    def ready?
      @enabled && [username, password, server_name].all?(&:present?)
    end

    def identity
      Digest::SHA256.hexdigest(
        [@enabled, username, password, server_name].to_json
      )
    end

    def credential_identity
      Digest::SHA256.hexdigest([username, password].to_json)
    end
  end
end

# frozen_string_literal: true

# name: discourse-dcs-server-status
# about: Live Eagle Dynamics DCS server status cards in forum posts.
# version: 0.1.0
# authors: fearlessfrog
# url: https://github.com/fearlessfrog/discourse-dcs-server-status
# required_version: 2026.10.0-latest

enabled_site_setting :dcs_server_status_enabled
register_asset "stylesheets/dcs-server-status.scss"

module ::DcsServerStatus
  PLUGIN_NAME = "discourse-dcs-server-status"
end

require_relative "lib/dcs_server_status/engine"

after_initialize do
  add_admin_route(
    "dcs_server_status.title",
    "discourse-dcs-server-status",
    use_new_show_route: true
  )

  on(:site_setting_changed) do |name, _old_value, _new_value|
    next unless name.to_s.start_with?("dcs_server_status_")

    if %w[dcs_server_status_username dcs_server_status_password].include?(
         name.to_s
       )
      DcsServerStatus::Store.clear_session!
    end

    if %w[
         dcs_server_status_enabled
         dcs_server_status_username
         dcs_server_status_password
         dcs_server_status_server_name
       ].include?(name.to_s)
      DcsServerStatus::Store.clear_status!
    end

    if DcsServerStatus::Configuration.new.ready?
      Jobs.enqueue(:dcs_server_status_refresh)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DCS status endpoints", :dcs_server_status do
  before { configure_dcs }

  fab!(:admin)
  fab!(:user)

  describe "GET /dcs-status.json" do
    it "serves guests cached fields without querying ED or exposing credentials" do
      config = DcsServerStatus::Configuration.new
      DcsServerStatus::Store.write_snapshot(
        {
          "status" => "online",
          "server" => {
            "name" => config.server_name
          },
          "last_success_at" => Time.now.to_i
        },
        config
      )

      get "/dcs-status.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.keys).to contain_exactly(
        "status",
        "stale",
        "last_success_at",
        "server",
        "server_name"
      )
      expect(response.body).not_to include(config.username, config.password)
      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(
        a_request(:any, /digitalcombatsimulator\.com/)
      ).not_to have_been_made
    end

    it "requires authentication on login-required forums" do
      SiteSetting.login_required = true
      get "/dcs-status.json"
      expect(response.status).to eq(403)

      sign_in(user)
      get "/dcs-status.json"
      expect(response.status).to eq(200)
    end

    it "updates the mission clock from cache without queuing a refresh or clearing the session" do
      stub_ed([ed_server("MISSION_TIME" => "65622")])
      DcsServerStatus::Refresh.call
      config = DcsServerStatus::Configuration.new
      snapshot = DcsServerStatus::Store.snapshot(config)
      session = DcsServerStatus::Store.session(config)
      Jobs::DcsServerStatusRefresh.jobs.clear

      [["04:40", 82_422], ["00:00", 65_622], ["", nil]].each do |offset, clock|
        SiteSetting.dcs_server_status_mission_start_time_offset = offset
        get "/dcs-status.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["server"]).to include(
          "mission_time_seconds" => 65_622,
          "mission_clock_seconds" => clock
        )
        expect(DcsServerStatus::Configuration.new.identity).to eq(
          config.identity
        )
        expect(DcsServerStatus::Store.snapshot(config)).to eq(snapshot)
        expect(DcsServerStatus::Store.session(config)).to eq(session)
        expect(Jobs::DcsServerStatusRefresh.jobs).to be_empty
      end

      expect(
        a_request(:get, DcsServerStatus::EdClient::LIST_URL)
      ).to have_been_made.twice
      expect(
        a_request(:post, DcsServerStatus::EdClient::LOGIN_URL)
      ).to have_been_made.once
    end

    it "returns unavailable when the plugin is disabled" do
      SiteSetting.dcs_server_status_enabled = false
      get "/dcs-status.json"
      expect(response.status).to eq(404)
    end

    it "keeps credentials out of visitor site settings" do
      settings = SiteSetting.client_settings_json
      expect(settings).not_to include(
        "dcs_server_status_password",
        "dcs_server_status_username"
      )
    end
  end

  describe "admin connection controls" do
    it "restricts diagnostics and refreshes to administrators" do
      get "/admin/plugins/discourse-dcs-server-status/connection.json"
      expect(response.status).to eq(403)

      sign_in(user)
      post "/admin/plugins/discourse-dcs-server-status/refresh.json"
      expect(response.status).to eq(403)

      sign_in(admin)
      get "/admin/plugins/discourse-dcs-server-status/connection.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body).to include("configured" => true)
    end

    it "queues refresh without putting credentials into the job arguments" do
      sign_in(admin)
      Jobs::DcsServerStatusRefresh.jobs.clear

      post "/admin/plugins/discourse-dcs-server-status/refresh.json"

      expect(response.status).to eq(202)
      expect(response.parsed_body).to eq("queued" => true)
      expect(Jobs::DcsServerStatusRefresh.jobs.size).to eq(1)
      expect(Jobs::DcsServerStatusRefresh.jobs.to_json).not_to include(
        SiteSetting.dcs_server_status_username,
        SiteSetting.dcs_server_status_password
      )
    end

    it "rejects a refresh while configuration is incomplete" do
      sign_in(admin)
      SiteSetting.dcs_server_status_password = ""
      post "/admin/plugins/discourse-dcs-server-status/refresh.json"
      expect(response.status).to eq(400)
    end
  end
end

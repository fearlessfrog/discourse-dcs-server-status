# frozen_string_literal: true

require "rails_helper"

RSpec.describe DcsServerStatus::Refresh, :dcs_server_status do
  before { configure_dcs }

  describe ".call" do
    it "serializes overlapping refreshes and avoids a second ED poll" do
      stub_ed_login
      entered = Queue.new
      release = Queue.new
      requests = 0
      stub_request(:get, DcsServerStatus::EdClient::LIST_URL).to_return do
        requests += 1
        if requests == 1
          entered << true
          release.pop
        end
        { body: { "SERVERS" => [ed_server] }.to_json }
      end

      first = Thread.new { described_class.call }
      Timeout.timeout(5) { entered.pop }
      second = Thread.new { described_class.call }
      release << true
      [first, second].each(&:value)

      expect(DcsServerStatus::Store.public_status[:status]).to eq("online")
      expect(
        a_request(:get, DcsServerStatus::EdClient::LIST_URL)
      ).to have_been_made.twice
    ensure
      release << true if release
      [first, second].compact.each { |thread| thread.join(5) }
    end

    it "normalizes the selected server without exposing other servers or HTML descriptions" do
      stub_ed([ed_server, ed_server("NAME" => "Unrelated")])

      described_class.call

      result = DcsServerStatus::Store.public_status
      expect(result[:status]).to eq("online")
      expect(result[:stale]).to eq(false)
      expect(result[:server]).to eq(
        "name" => "Example DCS Server",
        "ip_address" => "192.0.2.10",
        "port" => 10_308,
        "mission" => "Foothold & Cold War",
        "mission_time_seconds" => 96_898,
        "players" => 0,
        "players_max" => 16
      )
    end

    it "reports not listed only after a valid server-list response" do
      stub_ed([])
      described_class.call

      expect(DcsServerStatus::Store.public_status).to include(
        status: "not_listed",
        stale: false,
        server: nil
      )
    end

    it "reports duplicate names and invalid numbers as unknown with admin diagnostics" do
      stub_ed([ed_server, ed_server("PORT" => "10309")])
      described_class.call
      expect(DcsServerStatus::Store.diagnostics).to include(
        status: "unknown",
        error: "ambiguous_server_name"
      )

      stub_ed([ed_server("PLAYERS" => "garbage")])
      described_class.call(force: true)
      expect(DcsServerStatus::Store.diagnostics).to include(
        status: "unknown",
        error: "invalid_response"
      )
    end

    it "accepts a missing mission without inventing mission time or player counts" do
      stub_ed([ed_server("MISSION_NAME" => nil, "MISSION_TIME" => "0")])
      described_class.call

      expect(DcsServerStatus::Store.public_status[:server]).to include(
        "mission" => "",
        "mission_time_seconds" => 0
      )
    end

    it "keeps the last successful result stale during failures and recovers on success" do
      stub_ed
      described_class.call
      successful = DcsServerStatus::Store.public_status

      stub_request(:get, DcsServerStatus::EdClient::LIST_URL).to_return(
        body: "bad JSON"
      )
      described_class.call(force: true)
      expect(DcsServerStatus::Store.public_status).to include(
        status: "online",
        stale: true,
        server: successful[:server],
        last_success_at: successful[:last_success_at]
      )

      stub_ed([ed_server("PLAYERS" => "3")])
      described_class.call(force: true)
      expect(DcsServerStatus::Store.public_status[:stale]).to eq(false)
      expect(DcsServerStatus::Store.public_status[:server]["players"]).to eq(3)
    end

    it "marks delayed polling stale and discards results older than 24 hours" do
      freeze_time
      stub_ed
      described_class.call

      freeze_time(Time.now + 11.minutes)
      expect(DcsServerStatus::Store.public_status[:stale]).to eq(true)

      freeze_time(Time.now + 24.hours)
      expect(DcsServerStatus::Store.public_status).to include(
        status: "unknown",
        server: nil
      )
    end

    it "respects the polling interval and allows a forced refresh" do
      freeze_time
      stub_ed
      described_class.call
      described_class.call
      expect(
        a_request(:get, DcsServerStatus::EdClient::LIST_URL)
      ).to have_been_made.twice

      freeze_time(Time.now + 5.minutes)
      described_class.call
      described_class.call(force: true)
      expect(
        a_request(:get, DcsServerStatus::EdClient::LIST_URL)
      ).to have_been_made.times(4)
    end

    it "uses the configured two-minute interval from the scheduled job" do
      freeze_time
      SiteSetting.dcs_server_status_poll_interval_minutes = 2
      stub_ed
      job = Jobs::DcsServerStatusPoll.new
      job.execute({})

      freeze_time(Time.now + 1.minute)
      job.execute({})
      expect(
        a_request(:get, DcsServerStatus::EdClient::LIST_URL)
      ).to have_been_made.twice

      freeze_time(Time.now + 1.minute)
      job.execute({})
      expect(
        a_request(:get, DcsServerStatus::EdClient::LIST_URL)
      ).to have_been_made.times(3)
    end

    it "queues a refresh only when enabled configuration is complete" do
      SiteSetting.dcs_server_status_enabled = false
      SiteSetting.dcs_server_status_username = ""
      Jobs::DcsServerStatusRefresh.jobs.clear

      SiteSetting.dcs_server_status_enabled = true
      expect(Jobs::DcsServerStatusRefresh.jobs).to be_empty

      SiteSetting.dcs_server_status_username = "test-monitor"
      expect(Jobs::DcsServerStatusRefresh.jobs.size).to eq(1)
    end

    it "stops polling when disabled or incompletely configured" do
      SiteSetting.dcs_server_status_enabled = false
      described_class.call(force: true)
      SiteSetting.dcs_server_status_enabled = true
      SiteSetting.dcs_server_status_password = ""
      described_class.call(force: true)

      expect(
        a_request(:any, /digitalcombatsimulator\.com/)
      ).not_to have_been_made
    end

    it "clears status on server changes and discards an in-flight result for old configuration" do
      stub_ed
      described_class.call
      SiteSetting.dcs_server_status_server_name = "Another server"
      expect(DcsServerStatus::Store.public_status).to include(
        status: "unknown",
        server: nil
      )

      stub_request(:get, DcsServerStatus::EdClient::LIST_URL).to_return do
        SiteSetting.dcs_server_status_server_name = "New configuration"
        {
          body: { "SERVERS" => [ed_server("NAME" => "Another server")] }.to_json
        }
      end
      described_class.call(force: true)
      expect(DcsServerStatus::Store.public_status).to include(
        status: "unknown",
        server_name: "New configuration",
        server: nil
      )
    end

    it "clears the saved ED session when credentials change" do
      stub_ed
      described_class.call
      SiteSetting.dcs_server_status_password = "changed-password"

      expect(
        DcsServerStatus::Store.session(DcsServerStatus::Configuration.new)
      ).to eq([])
      expect(DcsServerStatus::Store.public_status[:server]).to be_nil
    end
  end
end

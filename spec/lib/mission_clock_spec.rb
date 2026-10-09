# frozen_string_literal: true

require "rails_helper"

RSpec.describe DcsServerStatus::Store, :dcs_server_status do
  before { configure_dcs }

  def cache_elapsed(seconds)
    described_class.write_snapshot(
      {
        "status" => "online",
        "last_success_at" => Time.now.to_i,
        "server" => {
          "mission_time_seconds" => seconds
        }
      },
      DcsServerStatus::Configuration.new
    )
  end

  it "leaves the offset optional and the clock null by default" do
    cache_elapsed(65_622)
    expect(SiteSetting.dcs_server_status_mission_start_time_offset).to eq("")
    expect(DcsServerStatus::Configuration.new.ready?).to eq(true)
    expect(described_class.public_status[:server]).to include(
      "mission_time_seconds" => 65_622,
      "mission_clock_seconds" => nil
    )
  end

  [
    ["00:00", 0, 0],
    ["04:40", 0, 16_800],
    ["04:40", 65_622, 82_422],
    ["23:00", 7200, 3600],
    ["04:40:30", 172_801, 16_831],
    ["23:59:59", 1, 0]
  ].each do |offset, elapsed, expected|
    it "calculates #{offset} plus #{elapsed} seconds as #{expected} seconds into the day" do
      SiteSetting.dcs_server_status_mission_start_time_offset = offset
      cache_elapsed(elapsed)
      expect(
        described_class.public_status[:server]["mission_clock_seconds"]
      ).to eq(expected)
    end
  end

  [
    "24:00",
    "04:60",
    "04:40:60",
    "4:40",
    "04:4",
    "noon",
    "-1:00",
    "04:40\n"
  ].each do |offset|
    it "rejects invalid start time #{offset.inspect}" do
      expect do
        SiteSetting.dcs_server_status_mission_start_time_offset = offset
      end.to raise_error(Discourse::InvalidParameters)
      expect(SiteSetting.dcs_server_status_mission_start_time_offset).to eq("")
    end
  end

  it "provides a useful validation message" do
    expect do
      SiteSetting.dcs_server_status_mission_start_time_offset = "24:00"
    end.to raise_error(Discourse::InvalidParameters, /HH:MM/)
  end

  it "keeps the raw cache unchanged and lets an admin clear the offset" do
    cache_elapsed(0)
    config = DcsServerStatus::Configuration.new
    snapshot = described_class.snapshot(config)
    SiteSetting.dcs_server_status_mission_start_time_offset = "04:40"
    described_class.public_status
    expect(described_class.snapshot(config)).to eq(snapshot)

    SiteSetting.dcs_server_status_mission_start_time_offset = ""
    expect(
      described_class.public_status[:server]["mission_clock_seconds"]
    ).to be_nil
  end

  it "keeps the fixed offset when the mission changes or restarts" do
    SiteSetting.dcs_server_status_mission_start_time_offset = "04:40"
    stub_ed([ed_server("MISSION_TIME" => "65622")])
    DcsServerStatus::Refresh.call
    expect(
      described_class.public_status[:server]["mission_clock_seconds"]
    ).to eq(82_422)

    stub_ed([ed_server("MISSION_NAME" => "New mission", "MISSION_TIME" => "0")])
    DcsServerStatus::Refresh.call(force: true)
    expect(described_class.public_status[:server]).to include(
      "mission" => "New mission",
      "mission_time_seconds" => 0,
      "mission_clock_seconds" => 16_800
    )
  end

  it "uses the last observation during failures without advancing either clock" do
    freeze_time
    SiteSetting.dcs_server_status_mission_start_time_offset = "04:40"
    cache_elapsed(65_622)
    server = described_class.public_status[:server]
    freeze_time(Time.now + 11.minutes)
    expect(described_class.public_status).to include(
      stale: true,
      server: server
    )

    stub_request(:get, DcsServerStatus::EdClient::LOGIN_URL).to_timeout
    DcsServerStatus::Refresh.call(force: true)
    expect(described_class.public_status).to include(
      stale: true,
      server: server
    )

    stub_ed([ed_server("MISSION_TIME" => "0")])
    DcsServerStatus::Refresh.call(force: true)
    expect(described_class.public_status).to include(stale: false)
    expect(
      described_class.public_status[:server]["mission_clock_seconds"]
    ).to eq(16_800)

    freeze_time(Time.now + 24.hours)
    expect(described_class.public_status).to include(
      status: "unknown",
      server: nil
    )
  end

  it "does not create a clock for a missing elapsed value or absent server" do
    SiteSetting.dcs_server_status_mission_start_time_offset = "04:40"
    cache_elapsed(nil)
    expect(
      described_class.public_status[:server]["mission_clock_seconds"]
    ).to be_nil

    described_class.clear_status!
    expect(described_class.public_status[:server]).to be_nil
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe DcsServerStatus::HeaderUrlValidator, :dcs_server_status do
  before { configure_dcs }

  [
    "",
    "/",
    "/t/example-server-status/123?u=example#post_2",
    "https://example.org/status",
    "http://example.org/status"
  ].each do |url|
    it "accepts #{url.inspect} as a badge destination" do
      SiteSetting.dcs_server_status_header_url = url
      expect(SiteSetting.dcs_server_status_header_url).to eq(url)
    end
  end

  [
    "javascript:alert(1)",
    "data:text/html,test",
    "//example.org/status",
    "https://",
    "https://user:password@example.org/status",
    "/\\example.org",
    "https://example.org/invalid path",
    "https://example.org:99999/status",
    "https://example.org/\nstatus",
    "https://example.org/#{"a" * 2048}"
  ].each do |url|
    it "rejects an unsafe or malformed destination #{url[0, 70].inspect}" do
      expect { SiteSetting.dcs_server_status_header_url = url }.to raise_error(
        Discourse::InvalidParameters
      )
    end
  end

  it "defaults to a disabled badge and blank destination" do
    expect(SiteSetting.dcs_server_status_header_enabled).to eq(false)
    expect(SiteSetting.dcs_server_status_header_url).to eq("")
  end

  it "changes presentation without refreshing ED or clearing either cache" do
    config = DcsServerStatus::Configuration.new
    DcsServerStatus::Store.write_snapshot(
      { "status" => "online", "last_success_at" => Time.now.to_i },
      config
    )
    DcsServerStatus::Store.write_session(["fixture-cookie"], config)
    snapshot = DcsServerStatus::Store.snapshot(config)
    Jobs::DcsServerStatusRefresh.jobs.clear

    SiteSetting.dcs_server_status_header_enabled = true
    SiteSetting.dcs_server_status_header_url = "/t/example-server-status/123"
    SiteSetting.dcs_server_status_header_enabled = false

    expect(Jobs::DcsServerStatusRefresh.jobs).to be_empty
    expect(DcsServerStatus::Store.snapshot).to eq(snapshot)
    expect(
      DcsServerStatus::Store.session(DcsServerStatus::Configuration.new)
    ).to eq(["fixture-cookie"])
    expect(a_request(:any, /digitalcombatsimulator\.com/)).not_to have_been_made
  end
end

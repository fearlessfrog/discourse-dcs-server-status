# frozen_string_literal: true

require "rails_helper"

RSpec.describe DcsServerStatus::EdClient, :dcs_server_status do
  before { configure_dcs }

  describe "#servers" do
    it "submits hidden login fields and keeps cookies across redirects" do
      stub_ed
      client = described_class.new(DcsServerStatus::Configuration.new)

      expect(client.servers).to eq([ed_server])
      expect(client.cookies).to include(
        hash_including("value" => "authenticated")
      )
      expect(
        a_request(:get, described_class::LIST_URL).with(
          headers: {
            "Cookie" => "ed_session=authenticated"
          }
        )
      ).to have_been_made.twice
    end

    it "uses a cached session without another login" do
      stub_request(:get, described_class::LIST_URL).with(
        headers: {
          "Cookie" => "ed_session=cached"
        }
      ).to_return(body: { "SERVERS" => [] }.to_json)
      cookies = [{ "name" => "ed_session", "value" => "cached", "path" => "/" }]

      expect(
        described_class.new(
          DcsServerStatus::Configuration.new,
          cookies: cookies
        ).servers
      ).to eq([])
      expect(a_request(:post, described_class::LOGIN_URL)).not_to have_been_made
    end

    it "reauthenticates once when a cached session returns the login page" do
      stub_ed
      stub_request(:get, described_class::LIST_URL).with(
        headers: {
          "Cookie" => "ed_session=expired"
        }
      ).to_return(body: ed_login_form)
      cookies = [
        { "name" => "ed_session", "value" => "expired", "path" => "/" }
      ]

      expect(
        described_class.new(
          DcsServerStatus::Configuration.new,
          cookies: cookies
        ).servers
      ).to eq([ed_server])
      expect(
        a_request(:post, described_class::LOGIN_URL)
      ).to have_been_made.once
    end

    it "reports rejected credentials without retrying the login repeatedly" do
      stub_ed_login
      stub_request(:get, described_class::LIST_URL).to_return(
        body: ed_login_form
      )

      expect {
        described_class.new(DcsServerStatus::Configuration.new).servers
      }.to raise_error(described_class::Error, "authentication_failed")
      expect(
        a_request(:post, described_class::LOGIN_URL)
      ).to have_been_made.once
    end

    it "rejects redirects to another host before sending credentials or cookies" do
      stub_request(:get, described_class::LOGIN_URL).to_return(
        status: 307,
        headers: {
          "Location" => "https://example.com/login"
        }
      )

      expect {
        described_class.new(DcsServerStatus::Configuration.new).servers
      }.to raise_error(described_class::Error, "unsafe_redirect")
      expect(a_request(:any, /example\.com/)).not_to have_been_made
    end

    it "rejects a login form that posts outside ED" do
      stub_request(:get, described_class::LOGIN_URL).to_return(
        body: ed_login_form.sub("/en/auth/", "https://example.com/login")
      )

      expect {
        described_class.new(DcsServerStatus::Configuration.new).servers
      }.to raise_error(described_class::Error, "unsafe_redirect")
    end

    it "recognizes an interactive CAPTCHA requirement" do
      stub_request(:get, described_class::LOGIN_URL).to_return(
        body: ed_login_form.sub("</form>", '<input name="captcha_word"></form>')
      )

      expect {
        described_class.new(DcsServerStatus::Configuration.new).servers
      }.to raise_error(described_class::Error, "interactive_login_required")
    end

    it "reports timeout, rate limit, and malformed JSON as safe error codes" do
      stub_ed_login
      stub_request(:get, described_class::LIST_URL).to_timeout
      expect {
        described_class.new(DcsServerStatus::Configuration.new).servers
      }.to raise_error(described_class::Error, "timeout")

      stub_request(:get, described_class::LIST_URL).to_return(status: 429)
      expect {
        described_class.new(DcsServerStatus::Configuration.new).servers
      }.to raise_error(described_class::Error, "rate_limited")

      stub_request(:get, described_class::LIST_URL).to_return(body: "not JSON")
      expect {
        described_class.new(DcsServerStatus::Configuration.new).servers
      }.to raise_error(described_class::Error, "invalid_response")
    end

    it "requires a complete server-list envelope" do
      stub_ed_login
      stub_request(:get, described_class::LIST_URL).to_return(
        body: { "PLAYERS_COUNT" => 5 }.to_json
      )

      expect {
        described_class.new(DcsServerStatus::Configuration.new).servers
      }.to raise_error(described_class::Error, "invalid_response")
    end

    it "rejects malformed server entries rather than reporting not listed" do
      stub_ed_login
      stub_request(:get, described_class::LIST_URL).to_return(
        body: { "SERVERS" => [{ "PLAYERS" => "2" }] }.to_json
      )

      expect {
        described_class.new(DcsServerStatus::Configuration.new).servers
      }.to raise_error(described_class::Error, "invalid_response")
    end
  end
end

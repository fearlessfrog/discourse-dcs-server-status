# frozen_string_literal: true

module DcsServerStatusSpecHelpers
  def configure_dcs
    SiteSetting.dcs_server_status_username = "monitor-test"
    SiteSetting.dcs_server_status_password = "fixture-password"
    SiteSetting.dcs_server_status_server_name = "Example DCS Server"
    SiteSetting.dcs_server_status_enabled = true
    DcsServerStatus::Store.clear_session!
    DcsServerStatus::Store.clear_status!
  end

  def ed_server(overrides = {})
    {
      "NAME" => "Example DCS Server",
      "IP_ADDRESS" => "192.0.2.10",
      "PORT" => "10308",
      "MISSION_NAME" => "Foothold &amp; Cold War",
      "MISSION_TIME" => "96898",
      "PLAYERS" => "0",
      "PLAYERS_MAX" => "16",
      "MISSION_TIME_FORMATTED" => "1d<br>02:54:58",
      "DESCRIPTION" => "<script>unsafe()</script>"
    }.merge(overrides)
  end

  def ed_login_form
    <<~HTML
      <form method="post" action="/en/auth/">
        <input type="hidden" name="AUTH_FORM" value="Y">
        <input type="hidden" name="sessid" value="test-csrf">
        <input name="USER_LOGIN"><input name="USER_PASSWORD" type="password">
      </form>
    HTML
  end

  def stub_ed_login
    stub_request(:get, DcsServerStatus::EdClient::LOGIN_URL).to_return(
      body: ed_login_form,
      headers: {
        "Set-Cookie" => "ed_session=initial; Path=/; Secure"
      }
    )
    stub_request(:post, DcsServerStatus::EdClient::LOGIN_URL).with(
      body:
        hash_including(
          "USER_LOGIN" => SiteSetting.dcs_server_status_username,
          "USER_PASSWORD" => SiteSetting.dcs_server_status_password,
          "sessid" => "test-csrf"
        ),
      headers: {
        "Cookie" => "ed_session=initial"
      }
    ).to_return(
      status: 302,
      headers: {
        "Location" => DcsServerStatus::EdClient::LIST_URL,
        "Set-Cookie" => "ed_session=authenticated; Path=/; Secure"
      }
    )
  end

  def stub_ed(servers = [ed_server])
    stub_ed_login
    stub_request(:get, DcsServerStatus::EdClient::LIST_URL).to_return(
      body: { "SERVERS" => servers }.to_json,
      headers: {
        "Content-Type" => "application/json"
      }
    )
  end
end

RSpec.configure do |config|
  config.include DcsServerStatusSpecHelpers, :dcs_server_status
end

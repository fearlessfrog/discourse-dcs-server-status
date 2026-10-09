# DCS Server Status plugin

A Discourse plugin that displays one Eagle Dynamics DCS server as a live card inside a post. Targeted and tested against Discourse **2026.10.0-latest**; older releases are not supported.

Put this on its own line, outside a code block:

```text
[dcs-status]
```

In the rich-text editor, typing or pasting this as a separate paragraph creates a status placeholder and saves the shortcode without escaping its brackets. Code examples and inline mentions of the shortcode stay literal. If an older post saved it as `\[dcs-status\]`, switch that post to Markdown editing and remove the backslashes.

The card shows the server name, whether ED lists it, player count/capacity, mission uptime, optional calculated in-game mission clock, mission, connection address, and last successful refresh. All cards refer to the single server configured by an admin, including cards in old posts. There is no bot account or header panel.

Colors inherit the forum's active Discourse theme, including light and dark palettes. No separate color configuration is required.

Example card with sample data in a dark theme:

![DCS server status card](docs/images/status-card.png)

[View the mobile example](docs/images/status-card-mobile.png).

## Installation

For a standard self-hosted Discourse Docker installation, add this entry to the existing plugin clone list under `hooks: after_code: exec: cmd:` in `/var/discourse/containers/app.yml`:

```yaml
- git clone https://github.com/<owner>/discourse-dcs-server-status.git
```

Replace `<owner>` with the account hosting the plugin repository. Then rebuild from the Discourse installation directory:

```sh
cd /var/discourse
./launcher rebuild app
```

Use your actual container name if it is not `app`. The rebuild briefly interrupts forum availability. It installs the plugin disabled by default.

## Configure and try it

1. Create a dedicated ED account and confirm it can access the server list when logged in. Do not use an account with purchased modules for monitoring.
2. In **Admin → Plugins → DCS Server Status plugin → Settings**, enter the ED username, ED password, and full server name exactly as ED lists it (for example, `Example DCS Server`), then enable the plugin.
3. Leave the polling interval at five minutes, or select two to five minutes.
4. Optionally set **Mission start time offset** to the mission's starting clock, such as `04:40` or `04:40:30`. Use 24-hour `HH:MM` or `HH:MM:SS`; leave blank to hide the calculated clock.
5. Open the plugin’s **Connection** tab, select **Refresh now**, wait a few seconds, and select **Reload diagnostics**. This is also the live unattended sign-in smoke test.
6. Create a test post with `[dcs-status]` on its own line. Check it as an admin, a regular member, and a guest if guest access is enabled.

If authentication fails, check the Connection diagnostic and log into ED manually with the dedicated account. CAPTCHA/interactive verification is not automated. Successful browser access alone does not establish that unattended Ruby login works.

## Behavior and credentials

- A Sidekiq scheduled job checks every minute whether the polling interval has elapsed. Requests to `/dcs-status.json` read Redis only; forum traffic does not cause ED requests.
- All visible cards share one browser request per minute. Requests pause in hidden tabs and stop after cards are removed. Status is a current view, not a historical snapshot of when the post was written.
- **Online** means the server appears in ED’s list. **Not listed by Eagle Dynamics** means a valid list did not contain its exact name; it is not proof that the server process is offline.
- Refresh failures retain the last successful result, marked **Stale**, for at most 24 hours. Results also become stale after twice the polling interval without a success. Before a first success, or after retention expires, status is unavailable.
- **Uptime** displays ED's `MISSION_TIME` elapsed duration for the current mission in `HH:MM:SS` format, with days for durations over 24 hours. It resets when the mission restarts; it is not the uptime of the DCS server process.
- **Mission time** is an optional calculated mission-local clock: `(configured starting clock + ED elapsed seconds) modulo 24 hours`. A start of `04:40` plus uptime `18:13:42` displays `22:53:42`. ED's JSON does not supply the starting clock; update the fixed offset manually whenever a mission starts at a different time. The setting applies to every mission until changed.
- Both times represent ED's last successful observation, including when marked **Stale**. The browser does not advance them between refreshes or convert the mission clock to the viewer's timezone. This is a calculated clock, not an independent reading of DCS's current time. Changing or clearing the offset uses the existing cache on the next card request without an ED refresh or sign-in.
- `/dcs-status.json` retains `server.mission_time_seconds` and adds `server.mission_clock_seconds` (seconds into the mission-local day, or `null` when unconfigured). Mission names are escaped text; ED descriptions and formatted HTML are not rendered.
- Names must be unique and match exactly. Update the setting if the server is renamed. IP changes are picked up automatically.
- Username and password are server-only site settings. The password uses Discourse’s masked secret field and filtered setting-change logs. Standard site-setting storage is not encrypted at rest: administrators, database operators, and backups can access it.
- ED cookies are kept server-side in namespaced Redis for up to 24 hours. Credentials and cookies are excluded from public payloads, job arguments, and plugin logs. Changing credentials clears the session and cached result.
- Visitors who can access the forum can access the configured server’s status and connection address. Discourse’s `login_required` setting also protects the JSON endpoint.
- Emails and views without JavaScript show an explanatory fallback instead of a live card. Disabling the plugin stops polling and leaves a readable fallback in existing cooked posts.

## Development and checks

Install or symlink this repository as `plugins/discourse-dcs-server-status` in a current Discourse development checkout. Run from that checkout:

```sh
LOAD_PLUGINS=1 bin/rspec plugins/discourse-dcs-server-status/spec
bin/qunit --standalone --target discourse-dcs-server-status
bin/lint --fix plugins/discourse-dcs-server-status
```

Tests mock ED HTTP requests and use fake credentials. CI uses Discourse’s official plugin workflow for backend and frontend checks. A live ED sign-in must be verified separately after installation; never put real credentials into fixtures or GitHub Actions.

The ED client was informed by [apx_bot’s login flow](https://github.com/farhannysf/apx_bot/blob/gvaw/main/utility.py); this plugin is an independent Ruby implementation. Discourse integrations follow its current plugin, Markdown, rich-editor, and admin-navigation APIs.

## Update or remove

Pull the latest plugin code through the normal Discourse rebuild process. To remove it, disable the plugin, remove its clone entry from the container configuration, and rebuild. No schema migrations or new database tables are installed.

## License

MIT.

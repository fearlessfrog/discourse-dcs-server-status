import { clearRender, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import DcsServerStatusCard, {
  formatMissionTime,
} from "discourse/plugins/discourse-dcs-server-status/discourse/components/dcs-server-status-card";

const fixture = {
  status: "online",
  stale: false,
  server_name: "Example DCS Server",
  last_success_at: "2026-10-08T12:00:00Z",
  server: {
    name: "Example DCS Server",
    players: 0,
    players_max: 16,
    mission: '<img src=x onerror="alert(1)"> & Cold War',
    mission_time_seconds: 96898,
    ip_address: "192.0.2.10",
    port: 10308,
  },
};

module("DCS status | Card", function (hooks) {
  setupRenderingTest(hooks);
  hooks.beforeEach(function () {
    this.requests = 0;
    pretender.get("/dcs-status.json", () => {
      this.requests++;
      return response(fixture);
    });
  });

  test("shows counts and elapsed time while escaping ED text", async function (assert) {
    await render(<template><DcsServerStatusCard /></template>);

    assert.dom(".dcs-server-status-card").includesText("0 / 16");
    assert.dom(".dcs-server-status-card").includesText("1d 02:54:58");
    assert.dom(".dcs-server-status-card").includesText(fixture.server.mission);
    assert.dom(".dcs-server-status-card img").doesNotExist();
    assert
      .dom(".dcs-server-status-card__address")
      .includesText("192.0.2.10:10308");
  });

  test("shares requests and releases the polling timer when cards disappear", async function (assert) {
    await render(
      <template><DcsServerStatusCard /><DcsServerStatusCard /></template>
    );

    assert.strictEqual(this.requests, 1);
    assert.dom(".dcs-server-status-card").exists({ count: 2 });

    await clearRender();
    const service = this.owner.lookup("service:dcs-server-status");
    assert.strictEqual(service.consumers, 0);
    assert.strictEqual(service.timer, null);
  });

  test("shows stale data and unknown status clearly", async function (assert) {
    pretender.get("/dcs-status.json", () =>
      response({ ...fixture, stale: true })
    );
    await render(<template><DcsServerStatusCard /></template>);
    assert.dom(".dcs-server-status-card__stale").includesText("Stale");

    const service = this.owner.lookup("service:dcs-server-status");
    service.payload = {
      status: "unknown",
      server: null,
      server_name: "Example DCS Server",
    };
    await settled();
    assert.dom(".dcs-server-status-card__status").hasText("Status unavailable");
    assert.dom(".dcs-server-status-card__details").doesNotExist();
  });

  test("formats zero and multi-day mission times", function (assert) {
    assert.strictEqual(formatMissionTime(0), "00:00:00");
    assert.strictEqual(formatMissionTime(65622), "18:13:42");
    assert.strictEqual(formatMissionTime(172801), "2d 00:00:01");
    assert.strictEqual(formatMissionTime(null), "—");
  });
});

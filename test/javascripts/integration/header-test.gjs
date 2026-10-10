import {
  clearRender,
  click,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import DcsServerStatusCard from "discourse/plugins/discourse-dcs-server-status/discourse/components/dcs-server-status-card";
import DcsServerStatusHeader from "discourse/plugins/discourse-dcs-server-status/discourse/components/dcs-server-status-header";
import { HEADER_MEDIA_QUERY } from "discourse/plugins/discourse-dcs-server-status/discourse/services/dcs-header-presentation";

const fixture = {
  status: "online",
  stale: false,
  server_name: "Example DCS Server",
  last_success_at: new Date().toISOString(),
  server: {
    name: "Example DCS Server",
    players: 0,
    players_max: 16,
    mission: "Example mission",
    mission_time_seconds: 65622,
    mission_clock_seconds: 82422,
    ip_address: "192.0.2.10",
    port: 10308,
  },
};

module("DCS status | Header badge", function (hooks) {
  setupRenderingTest(hooks, { anonymous: true });
  hooks.beforeEach(function () {
    this.settings = this.owner.lookup("service:site-settings");
    this.settings.dcs_server_status_enabled = true;
    this.settings.dcs_server_status_header_enabled = true;
    this.settings.dcs_server_status_header_url = "";
    this.preferences = this.owner.lookup("service:dcs-header-preference");
    this.preferences.setDismissed(false);
    this.query = new EventTarget();
    this.query.matches = true;
    const original = window.matchMedia.bind(window);
    sinon
      .stub(window, "matchMedia")
      .callsFake((query) =>
        query === HEADER_MEDIA_QUERY ? this.query : original(query)
      );
    this.requests = 0;
    pretender.get("/dcs-status.json", () => {
      this.requests++;
      return response(fixture);
    });
  });
  hooks.afterEach(async function () {
    await clearRender();
    this.preferences.setDismissed(false);
    sinon.restore();
  });

  test("shows two lines, the full accessible name, zero players and mission clock", async function (assert) {
    await render(<template><DcsServerStatusHeader /></template>);
    assert.dom(".dcs-header-first-line").includesText("Example DCS Server");
    assert.dom(".dcs-header-state").hasText("Online");
    assert.dom(".dcs-header-state").hasAttribute("data-status", "online");
    assert.dom(".dcs-header-second-line").includesText("22:53");
    assert.dom(".dcs-header-second-line").includesText("0/16 players");
    assert
      .dom(".dcs-header-trigger")
      .hasAttribute("title", "Example DCS Server");
    assert
      .dom(".dcs-header-trigger")
      .hasAttribute(
        "aria-label",
        "Example DCS Server, Online, Mission time 22:53, 0/16 players"
      );
  });

  test("shares polling with cards and popovers, including Escape and dismissal focus", async function (assert) {
    await render(
      <template><DcsServerStatusHeader /><DcsServerStatusCard /></template>
    );
    const service = this.owner.lookup("service:dcs-server-status");
    assert.strictEqual(this.requests, 1);
    assert.strictEqual(service.consumers, 2);
    await click(".dcs-header-trigger");
    assert.dom(".dcs-header-details .dcs-server-status-card").exists();
    assert.dom(".dcs-header-details").includesText("18:13:42");
    assert.dom(".dcs-header-details").includesText("22:53:42");
    assert.strictEqual(this.requests, 1);
    assert.strictEqual(service.consumers, 3);
    await triggerKeyEvent(document, "keydown", "Escape");
    assert.dom(".dcs-header-details").doesNotExist();
    assert.dom(".dcs-header-trigger").isFocused();
    assert.strictEqual(service.consumers, 2);

    await click(".dcs-header-trigger");
    await click(".dcs-header-dismiss");
    assert.dom(".dcs-header-details").doesNotExist();
    assert.dom(".dcs-header-restore").isFocused();
    assert.strictEqual(
      service.consumers,
      1,
      "the post card keeps its subscription"
    );
    await clearRender();
    assert.strictEqual(service.consumers, 0);
    assert.strictEqual(service.timer, null);
  });

  test("dismissal stops polling and restoration does not navigate", async function (assert) {
    this.settings.dcs_server_status_header_url = "/t/example-server-status/123";
    const route = sinon.stub(DiscourseURL, "routeTo");
    await render(<template><DcsServerStatusHeader /></template>);
    const service = this.owner.lookup("service:dcs-server-status");
    await click(".dcs-header-dismiss");
    assert.dom(".dcs-header-link").doesNotExist();
    assert.dom(".dcs-header-restore").doesNotIncludeText("DCS");
    assert.dom(".dcs-header-restore use").hasAttribute("href", "#jet-fighter");
    assert
      .dom(".dcs-header-restore")
      .hasAttribute("aria-label", "Show DCS header status");
    assert.true(this.preferences.dismissed);
    assert.strictEqual(service.consumers, 0);
    assert.strictEqual(service.timer, null);
    await click(".dcs-header-restore");
    assert.dom(".dcs-header-link").isFocused();
    assert.false(this.preferences.dismissed);
    assert.false(route.called);
    assert.strictEqual(this.requests, 1);
  });

  test("URL links preserve modifier clicks and use internal forum navigation", async function (assert) {
    this.settings.dcs_server_status_header_url = "/t/example-server-status/123";
    const route = sinon.stub(DiscourseURL, "routeTo");
    await render(<template><DcsServerStatusHeader /></template>);
    assert
      .dom(".dcs-header-link")
      .hasAttribute("href", "/t/example-server-status/123");
    assert.dom(".dcs-header-trigger").doesNotExist();
    await click(".dcs-header-link");
    assert.true(route.calledOnceWithExactly("/t/example-server-status/123"));

    const modified = new MouseEvent("click", {
      button: 0,
      ctrlKey: true,
      cancelable: true,
    });
    document.querySelector(".dcs-header-link").dispatchEvent(modified);
    assert.false(modified.defaultPrevented);
    assert.strictEqual(route.callCount, 1);
  });

  test("external destinations remain native links", async function (assert) {
    this.settings.dcs_server_status_header_url =
      "https://example.org/server-status";
    const internal = sinon.spy(DiscourseURL, "isInternal");
    const route = sinon.stub(DiscourseURL, "routeTo");
    await render(<template><DcsServerStatusHeader /></template>);
    const link = document.querySelector(".dcs-header-link");
    assert.strictEqual(
      link.getAttribute("href"),
      "https://example.org/server-status"
    );
    const event = new MouseEvent("click", { button: 0, cancelable: true });
    // Prevent the test browser leaving the harness after observing the handler.
    link.addEventListener("click", (e) => e.preventDefault(), { once: true });
    link.dispatchEvent(event);
    assert.true(internal.calledWith("https://example.org/server-status"));
    assert.false(route.called);
  });

  test("narrowing closes details and stops header polling without changing dismissal", async function (assert) {
    await render(<template><DcsServerStatusHeader /></template>);
    await click(".dcs-header-trigger");
    this.query.matches = false;
    this.query.dispatchEvent(new Event("change"));
    await settled();
    assert.dom(".dcs-header-status").doesNotExist();
    assert.dom(".dcs-header-details").doesNotExist();
    const service = this.owner.lookup("service:dcs-server-status");
    assert.strictEqual(service.consumers, 0);
    assert.strictEqual(service.timer, null);
    assert.false(this.preferences.dismissed);
    this.query.matches = true;
    this.query.dispatchEvent(new Event("change"));
    await settled();
    assert.dom(".dcs-header-trigger").exists();
    assert.strictEqual(this.requests, 1);
  });

  test("disabled settings and login-required guest access do not poll", async function (assert) {
    this.settings.dcs_server_status_header_enabled = false;
    await render(<template><DcsServerStatusHeader /></template>);
    assert.dom(".dcs-header-status").doesNotExist();
    assert.strictEqual(this.requests, 0);
    await clearRender();
    this.settings.dcs_server_status_header_enabled = true;
    this.settings.login_required = true;
    await render(<template><DcsServerStatusHeader /></template>);
    assert.dom(".dcs-header-status").doesNotExist();
    assert.strictEqual(this.requests, 0);
  });

  test("stale, missing-clock, midnight, not-listed and unavailable states stay explicit", async function (assert) {
    await render(<template><DcsServerStatusHeader /></template>);
    const service = this.owner.lookup("service:dcs-server-status");
    service.payload = {
      ...fixture,
      stale: true,
      server: { ...fixture.server, mission_clock_seconds: 0 },
    };
    await settled();
    assert.dom(".dcs-header-state").hasText("Stale");
    assert.dom(".dcs-header-state").hasAttribute("data-status", "stale");
    assert.dom(".dcs-header-clock").hasText("00:00");
    service.payload = {
      ...fixture,
      server: {
        ...fixture.server,
        mission_clock_seconds: null,
        name: "<script>hostile()</script> " + "Long server name ".repeat(20),
      },
    };
    await settled();
    assert.dom(".dcs-header-clock").doesNotExist();
    assert.dom(".dcs-header-name script").doesNotExist();
    assert.dom(".dcs-header-name").includesText("<script>hostile()</script>");
    service.payload = { ...fixture, status: "not_listed", server: null };
    await settled();
    assert.dom(".dcs-header-state").hasText("Not listed");
    assert.dom(".dcs-header-state").hasAttribute("data-status", "not_listed");
    assert.dom(".dcs-header-players").doesNotExist();
    service.payload = { ...fixture, status: "unknown", server: null };
    await settled();
    assert.dom(".dcs-header-state").hasText("Unavailable");
  });
});

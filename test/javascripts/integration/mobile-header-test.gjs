import {
  clearRender,
  click,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { addExtraSpriteSymbols } from "discourse/lib/svg-sprite-loader";
import DiscourseURL from "discourse/lib/url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import DcsServerStatusCard from "discourse/plugins/discourse-dcs-server-status/discourse/components/dcs-server-status-card";
import DcsServerStatusMobileHeader from "discourse/plugins/discourse-dcs-server-status/discourse/components/dcs-server-status-mobile-header";

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

module("DCS status | Mobile header", function (hooks) {
  setupRenderingTest(hooks, { anonymous: true });

  hooks.beforeEach(function () {
    this.settings = this.owner.lookup("service:site-settings");
    this.settings.dcs_server_status_enabled = true;
    this.settings.dcs_server_status_header_enabled = true;
    this.settings.dcs_server_status_header_url = "";
    this.site = this.owner.lookup("service:site");
    this.site.set("can_search", true);
    sinon.stub(this.site, "mobileView").get(() => true);
    this.router = this.owner.lookup("service:router");
    this.route = sinon
      .stub(this.router, "currentRouteName")
      .value("discovery.latest");
    this.header = this.owner.lookup("service:header");
    this.header.clearTopic();
    this.preferences = this.owner.lookup("service:dcs-header-preference");
    this.preferences.setDismissed(true);
    this.service = this.owner.lookup("service:dcs-server-status");
    this.requests = 0;
    pretender.get("/dcs-status.json", () => {
      this.requests++;
      return response(fixture);
    });
  });

  hooks.afterEach(async function () {
    await clearRender();
    this.preferences.setDismissed(false);
    document
      .querySelector('#svg-sprites symbol[id="mudspike-fighter-jet"]')
      ?.remove();
    sinon.restore();
  });

  test("is idle until opened and leaves desktop dismissal unchanged", async function (assert) {
    await render(<template><DcsServerStatusMobileHeader /></template>);
    assert
      .dom(".dcs-mobile-header-trigger")
      .hasAttribute("aria-label", "Show DCS server status");
    assert
      .dom(".dcs-mobile-header-trigger")
      .hasAttribute("aria-expanded", "false");
    assert.strictEqual(this.requests, 0);
    assert.strictEqual(this.service.consumers, 0);
    await click(".dcs-mobile-header-trigger");
    assert
      .dom(".dcs-mobile-header-trigger")
      .hasAttribute("aria-expanded", "true");
    assert.dom(".dcs-mobile-header-details").includesText("0 / 16");
    assert.dom(".dcs-mobile-header-details").includesText("22:53:42");
    assert.dom(".dcs-mobile-header-details").includesText("18:13:42");
    assert.dom(".dcs-mobile-header-link").doesNotExist();
    assert.dom(".fk-d-menu-modal").doesNotExist();
    assert.strictEqual(this.requests, 1);
    assert.strictEqual(this.service.consumers, 1);
    assert.notStrictEqual(this.service.timer, null);
    await click(".dcs-mobile-header-close");
    assert.dom(".dcs-mobile-header-details").doesNotExist();
    assert.dom(".dcs-mobile-header-trigger").isFocused();
    assert.strictEqual(this.service.consumers, 0);
    assert.strictEqual(this.service.timer, null);
    assert.true(this.preferences.dismissed);
  });

  test("supports repeat taps, keyboard opening, Escape and outside taps", async function (assert) {
    await render(
      <template>
        <span class="outside">Outside</span><DcsServerStatusMobileHeader />
      </template>
    );
    await click(".dcs-mobile-header-trigger");
    await click(".dcs-mobile-header-trigger");
    assert.dom(".dcs-mobile-header-details").doesNotExist();
    // A native button synthesizes click for keyboard activation.
    await triggerKeyEvent(".dcs-mobile-header-trigger", "keydown", "Enter");
    await click(".dcs-mobile-header-trigger");
    await triggerKeyEvent(document, "keydown", "Escape");
    assert.dom(".dcs-mobile-header-details").doesNotExist();
    assert.dom(".dcs-mobile-header-trigger").isFocused();
    await click(".dcs-mobile-header-trigger");
    await triggerEvent(".outside", "pointerdown");
    assert.dom(".dcs-mobile-header-details").doesNotExist();
    assert.strictEqual(this.service.consumers, 0);
  });

  test("shares requests with post cards and releases only its own subscription", async function (assert) {
    await render(
      <template>
        <DcsServerStatusMobileHeader /><DcsServerStatusCard />
      </template>
    );
    assert.strictEqual(this.requests, 1);
    await click(".dcs-mobile-header-trigger");
    assert.strictEqual(this.requests, 1);
    assert.strictEqual(this.service.consumers, 2);
    await click(".dcs-mobile-header-close");
    assert.strictEqual(this.service.consumers, 1);
    assert.notStrictEqual(this.service.timer, null);
  });

  test("closes on navigation and when the topic title hides header controls", async function (assert) {
    await render(<template><DcsServerStatusMobileHeader /></template>);
    await click(".dcs-mobile-header-trigger");
    this.router.trigger("routeWillChange", {});
    await settled();
    assert.dom(".dcs-mobile-header-details").doesNotExist();
    assert.strictEqual(this.service.consumers, 0);
    await click(".dcs-mobile-header-trigger");
    this.header.topicInfo = {};
    this.header.mainTopicTitleVisible = false;
    await settled();
    assert.dom(".dcs-mobile-header").doesNotExist();
    assert.dom(".dcs-mobile-header-details").doesNotExist();
    assert.strictEqual(this.service.consumers, 0);
    this.header.clearTopic();
    await settled();
    assert
      .dom(".dcs-mobile-header-trigger")
      .hasAttribute("aria-expanded", "false");
  });

  test("follows search visibility and respects settings, access and desktop mode", async function (assert) {
    for (const setting of [
      "dcs_server_status_enabled",
      "dcs_server_status_header_enabled",
      "login_required",
    ]) {
      this.settings[setting] = setting === "login_required";
      await render(<template><DcsServerStatusMobileHeader /></template>);
      assert.dom(".dcs-mobile-header").doesNotExist(setting);
      await clearRender();
      this.settings[setting] = setting !== "login_required";
    }
    this.site.set("can_search", false);
    await render(<template><DcsServerStatusMobileHeader /></template>);
    assert.dom(".dcs-mobile-header").doesNotExist("search is unavailable");
    await clearRender();
    this.site.set("can_search", true);
    const hider = {};
    this.header.registerHider(hider, ["search"]);
    await render(<template><DcsServerStatusMobileHeader /></template>);
    assert
      .dom(".dcs-mobile-header")
      .doesNotExist("search is explicitly hidden");
    assert.strictEqual(this.requests, 0);
  });

  test("excluded routes and desktop mode have no icon or requests", async function (assert) {
    this.route.value("full-page-search");
    await render(<template><DcsServerStatusMobileHeader /></template>);
    assert.dom(".dcs-mobile-header").doesNotExist();
    await clearRender();
    this.route.value("discovery.latest");
    sinon.restore();
    sinon.stub(this.site, "mobileView").get(() => false);
    await render(<template><DcsServerStatusMobileHeader /></template>);
    assert.dom(".dcs-mobile-header").doesNotExist();
    assert.strictEqual(this.requests, 0);
  });

  test("uses the theme fighter symbol even when the sprite arrives after mounting", async function (assert) {
    await render(<template><DcsServerStatusMobileHeader /></template>);
    assert
      .dom(".dcs-mobile-header-trigger use")
      .hasAttribute("href", "#jet-fighter");
    addExtraSpriteSymbols([
      {
        id: "mudspike-fighter-jet",
        symbol:
          '<symbol id="mudspike-fighter-jet" viewBox="0 0 10 10"><path d="M0 0L10 10"/></symbol>',
      },
    ]);
    await settled();
    assert
      .dom(".dcs-mobile-header-trigger use")
      .hasAttribute("href", "#mudspike-fighter-jet");
    assert.strictEqual(this.requests, 0);
  });

  test("always opens details with an internal destination and preserves modifier clicks", async function (assert) {
    this.settings.dcs_server_status_header_url = "/t/example-server-status/123";
    const route = sinon.stub(DiscourseURL, "routeTo");
    await render(<template><DcsServerStatusMobileHeader /></template>);
    await click(".dcs-mobile-header-trigger");
    assert.false(route.called);
    assert.dom(".dcs-mobile-header-link").hasText("More server information");
    assert
      .dom(".dcs-mobile-header-link")
      .hasAttribute("href", "/t/example-server-status/123");
    const modified = new MouseEvent("click", {
      button: 0,
      ctrlKey: true,
      cancelable: true,
    });
    document.querySelector(".dcs-mobile-header-link").dispatchEvent(modified);
    assert.false(modified.defaultPrevented);
    assert.false(route.called);
    await click(".dcs-mobile-header-link");
    assert.true(route.calledOnceWithExactly("/t/example-server-status/123"));
  });

  test("external destinations are native links inside the details", async function (assert) {
    this.settings.dcs_server_status_header_url =
      "https://example.org/server-status";
    const route = sinon.stub(DiscourseURL, "routeTo");
    await render(<template><DcsServerStatusMobileHeader /></template>);
    await click(".dcs-mobile-header-trigger");
    const link = document.querySelector(".dcs-mobile-header-link");
    assert.dom(link).hasAttribute("href", "https://example.org/server-status");
    const event = new MouseEvent("click", { button: 0, cancelable: true });
    link.addEventListener("click", (e) => e.preventDefault(), { once: true });
    link.dispatchEvent(event);
    assert.false(route.called);
    await click(".dcs-mobile-header-close");
    assert.false(route.called, "closing never follows the destination");
  });

  test("loading, failed, stale, missing-clock and not-listed details use the existing card", async function (assert) {
    pretender.get("/dcs-status.json", () => response(503, {}));
    await render(<template><DcsServerStatusMobileHeader /></template>);
    await click(".dcs-mobile-header-trigger");
    assert.dom(".dcs-server-status-card__status").hasText("Status unavailable");
    this.service.payload = {
      ...fixture,
      stale: true,
      server: { ...fixture.server, mission_clock_seconds: null },
    };
    await settled();
    assert.dom(".dcs-server-status-card__stale").includesText("Stale");
    assert.dom(".dcs-server-status-card__clock").doesNotExist();
    this.service.payload = { ...fixture, status: "not_listed", server: null };
    await settled();
    assert
      .dom(".dcs-server-status-card__status")
      .hasText("Not listed by Eagle Dynamics");
    assert.dom(".dcs-server-status-card__details").doesNotExist();
    this.service.failed = false;
    this.service.payload = null;
    await settled();
    assert.dom(".dcs-server-status-card__status").hasText("Loading…");
  });
});

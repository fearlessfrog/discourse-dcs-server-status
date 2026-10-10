import { tracked } from "@glimmer/tracking";
import { clearRender, click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { addExtraSpriteSymbols } from "discourse/lib/svg-sprite-loader";
import DiscourseURL from "discourse/lib/url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import DcsServerStatusHeader from "discourse/plugins/discourse-dcs-server-status/discourse/components/dcs-server-status-header";
import DcsServerStatusMobileHeader from "discourse/plugins/discourse-dcs-server-status/discourse/components/dcs-server-status-mobile-header";
import { HEADER_MEDIA_QUERY } from "discourse/plugins/discourse-dcs-server-status/discourse/services/dcs-header-presentation";

class Viewport {
  @tracked mobile = false;
}

const Header = <template>
  <DcsServerStatusHeader />
  <ul class="d-header-icons"><DcsServerStatusMobileHeader /></ul>
</template>;

module("DCS status | Responsive header", function (hooks) {
  setupRenderingTest(hooks, { anonymous: true });

  hooks.beforeEach(function () {
    this.settings = this.owner.lookup("service:site-settings");
    this.settings.dcs_server_status_enabled = true;
    this.settings.dcs_server_status_header_enabled = true;
    this.settings.dcs_server_status_header_url = "";
    this.site = this.owner.lookup("service:site");
    this.site.set("can_search", true);
    this.viewport = new Viewport();
    sinon.stub(this.site, "mobileView").get(() => this.viewport.mobile);
    this.query = new EventTarget();
    this.query.matches = true;
    const original = window.matchMedia.bind(window);
    sinon
      .stub(window, "matchMedia")
      .callsFake((query) =>
        query === HEADER_MEDIA_QUERY ? this.query : original(query)
      );
    this.header = this.owner.lookup("service:header");
    this.header.clearTopic();
    this.preferences = this.owner.lookup("service:dcs-header-preference");
    this.preferences.setDismissed(false);
    this.status = this.owner.lookup("service:dcs-server-status");
    this.requests = 0;
    pretender.get("/dcs-status.json", () => {
      this.requests++;
      return response({
        status: "online",
        stale: false,
        server_name: "Example DCS Server",
        last_success_at: new Date().toISOString(),
        server: {
          name: "Example DCS Server",
          players: 2,
          players_max: 16,
          mission: "Example mission",
          mission_time_seconds: 65622,
          mission_clock_seconds: 82422,
          ip_address: "192.0.2.10",
          port: 10308,
        },
      });
    });
    this.resize = async (width, forcedMobile = false) => {
      this.viewport.mobile = forcedMobile || width < 640;
      this.query.matches = width >= 1024;
      this.query.dispatchEvent(new Event("change"));
      await settled();
    };
  });

  hooks.afterEach(async function () {
    await clearRender();
    this.preferences.setDismissed(false);
    document
      .querySelector('#svg-sprites symbol[id="mudspike-fighter-jet"]')
      ?.remove();
    sinon.restore();
  });

  test("has one control across both breakpoints, including forced mobile", async function (assert) {
    await this.resize(639);
    await render(<template><Header /></template>);
    for (const width of [639, 640, 767, 768, 900, 1023]) {
      await this.resize(width);
      assert
        .dom(".dcs-mobile-header-trigger")
        .exists({ count: 1 }, `${width}px compact control`);
      assert
        .dom(".dcs-header-status")
        .doesNotExist(`${width}px has no full badge`);
      assert.strictEqual(
        this.status.consumers,
        0,
        "closed compact controls do not subscribe"
      );
    }
    assert.strictEqual(this.requests, 0);
    assert
      .dom(".dcs-compact-guest-controls .dcs-mobile-header-trigger")
      .exists("compact desktop guests use the position before authentication");
    await this.resize(1024);
    assert.dom(".dcs-header-trigger").exists();
    assert.dom(".dcs-mobile-header-trigger").doesNotExist();
    assert.strictEqual(this.status.consumers, 1);
    await this.resize(1280, true);
    assert.dom(".dcs-mobile-header-trigger").exists();
    assert.dom(".dcs-header-status").doesNotExist();
    assert.strictEqual(this.status.consumers, 0);
  });

  test("resizing closes both popovers and preserves dismissal and cached requests", async function (assert) {
    await render(<template><Header /></template>);
    await click(".dcs-header-trigger");
    assert.strictEqual(this.status.consumers, 2);
    await this.resize(900);
    assert.dom(".dcs-header-details").doesNotExist();
    assert.dom(".dcs-mobile-header-trigger").exists();
    assert.strictEqual(this.status.consumers, 0);
    assert.strictEqual(this.status.timer, null);
    await click(".dcs-mobile-header-trigger");
    assert.strictEqual(this.status.consumers, 1);
    await this.resize(1024);
    assert.dom(".dcs-mobile-header-details").doesNotExist();
    assert.dom(".dcs-header-trigger").exists();
    assert.strictEqual(this.status.consumers, 1);
    await click(".dcs-header-dismiss");
    await this.resize(900);
    await click(".dcs-mobile-header-trigger");
    assert.true(this.preferences.dismissed);
    await this.resize(1024);
    assert.dom(".dcs-mobile-header-details").doesNotExist();
    assert.dom(".dcs-header-restore").exists();
    assert.true(this.preferences.dismissed);
    assert.strictEqual(this.status.consumers, 0);
    assert.strictEqual(this.status.timer, null);
    assert.strictEqual(this.requests, 1, "mode changes reuse cached status");
  });

  test("shares the asynchronously loaded fighter icon and restores without navigation", async function (assert) {
    this.preferences.setDismissed(true);
    this.settings.dcs_server_status_header_url = "/t/example-server-status/123";
    const navigate = sinon.stub(DiscourseURL, "routeTo");
    await render(<template><Header /></template>);
    assert.dom(".dcs-header-restore use").hasAttribute("href", "#jet-fighter");
    addExtraSpriteSymbols([
      {
        id: "mudspike-fighter-jet",
        symbol:
          '<symbol id="mudspike-fighter-jet" viewBox="0 0 10 10"><path d="M0 0L10 10"/></symbol>',
      },
    ]);
    await settled();
    assert
      .dom(".dcs-header-restore use")
      .hasAttribute("href", "#mudspike-fighter-jet");
    await this.resize(900);
    assert
      .dom(".dcs-mobile-header-trigger use")
      .hasAttribute("href", "#mudspike-fighter-jet");
    await this.resize(1024);
    assert.strictEqual(this.requests, 0);
    await click(".dcs-header-restore");
    assert.dom(".dcs-header-link").isFocused();
    assert.dom(".dcs-header-details").doesNotExist();
    assert.false(this.preferences.dismissed);
    assert.false(navigate.called);
  });

  test("topic titles hide the icon on mobile but keep it on compact desktop", async function (assert) {
    await this.resize(900);
    await render(<template><Header /></template>);
    this.header.topicInfo = {};
    this.header.mainTopicTitleVisible = false;
    await settled();
    assert.dom(".dcs-mobile-header-trigger").exists();
    await this.resize(639);
    assert.dom(".dcs-mobile-header-trigger").doesNotExist();
    await this.resize(640);
    assert.dom(".dcs-mobile-header-trigger").exists();
    assert.strictEqual(this.requests, 0);
  });

  test("compact layouts preserve guest restrictions and disabled settings", async function (assert) {
    await this.resize(900);
    await render(<template><Header /></template>);
    this.settings.login_required = true;
    await settled();
    assert.dom(".dcs-mobile-header-trigger").doesNotExist();
    this.settings.login_required = false;
    this.settings.dcs_server_status_header_enabled = false;
    await settled();
    assert.dom(".dcs-mobile-header-trigger").doesNotExist();
    assert.strictEqual(this.requests, 0);
  });
});

import { click, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import KeyValueStore from "discourse/lib/key-value-store";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import {
  HEADER_HIDDEN_KEY,
  HEADER_STORE_NAMESPACE,
} from "discourse/plugins/discourse-dcs-server-status/discourse/services/dcs-header-preference";
import { HEADER_MEDIA_QUERY } from "discourse/plugins/discourse-dcs-server-status/discourse/services/dcs-header-presentation";

for (const mobile of [false, true]) {
  acceptance(
    `DCS status | ${mobile ? "Mobile" : "Desktop"} header`,
    function (needs) {
      needs.settings({
        dcs_server_status_enabled: true,
        dcs_server_status_header_enabled: true,
      });
      if (mobile) {
        needs.mobileView();
      }
      needs.pretender((server, helper) => {
        const topic = cloneJSON(topicFixtures["/t/130.json"]);
        topic.archetype = "regular";
        topic.post_stream.posts[0].cooked =
          '<div class="dcs-server-status-placeholder">DCS server status</div>';
        server.get("/t/130.json", () => helper.response(topic));
        server.get("/dcs-status.json", () =>
          helper.response({
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
          })
        );
      });
      needs.hooks.beforeEach(function () {
        this.container
          .lookup("service:dcs-header-preference")
          .setDismissed(false);
      });
      needs.hooks.afterEach(function () {
        new KeyValueStore(HEADER_STORE_NAMESPACE).remove(HEADER_HIDDEN_KEY);
      });
      if (mobile) {
        test("mobile icon opens shared details and closes across navigation and hidden controls", async function (assert) {
          await visit("/");
          const service = this.container.lookup("service:dcs-server-status");
          assert.dom(".dcs-mobile-header-trigger").exists();
          assert.dom(".d-header .dcs-header-status").doesNotExist();
          assert.strictEqual(service.consumers, 0);
          const icon = document.querySelector(".dcs-mobile-header");
          const search = document.querySelector(".search-dropdown");
          assert.strictEqual(
            icon.nextElementSibling,
            search,
            "the fighter is immediately before search"
          );
          await click(".dcs-mobile-header-trigger");
          assert.dom(".dcs-mobile-header-details").exists();
          assert.strictEqual(service.consumers, 1);
          await visit("/t/-/130");
          assert.dom(".dcs-mobile-header-details").doesNotExist();
          assert.dom(".cooked .dcs-server-status-card").exists();
          assert.strictEqual(service.consumers, 1);
          const header = this.container.lookup("service:header");
          header.mainTopicTitleVisible = true;
          await settled();
          await click(".dcs-mobile-header-trigger");
          assert.strictEqual(service.consumers, 2);
          header.mainTopicTitleVisible = false;
          await settled();
          assert.dom(".dcs-mobile-header-trigger").doesNotExist();
          assert.dom(".dcs-mobile-header-details").doesNotExist();
          assert.strictEqual(service.consumers, 1);
        });
      } else {
        test("header visibility, post cards and subscriptions survive topic navigation", async function (assert) {
          const assertBesideControls = (message) => {
            const badge = document
              .querySelector(".dcs-header-status")
              .getBoundingClientRect();
            const panel = document
              .querySelector(".d-header .panel")
              .getBoundingClientRect();
            const gap = panel.left - badge.right;
            assert.true(gap >= 0, `${message}: no overlap`);
            assert.true(gap <= 16, `${message}: no excess space`);
          };
          await visit("/t/-/130");
          assert.dom(".dcs-mobile-header").doesNotExist();
          const service = this.container.lookup("service:dcs-server-status");
          assert.dom(".cooked .dcs-server-status-card").exists();
          assert.dom(".before-header-panel-outlet .dcs-header-status").exists();
          assert.dom(".dcs-header-clock").hasText("22:53");
          const badge = document
            .querySelector(".dcs-header-status")
            .getBoundingClientRect();
          const firstLine = document
            .querySelector(".dcs-header-first-line")
            .getBoundingClientRect();
          const secondLine = document
            .querySelector(".dcs-header-second-line")
            .getBoundingClientRect();
          const header = document
            .querySelector(".d-header")
            .getBoundingClientRect();
          const panel = document
            .querySelector(".d-header .panel")
            .getBoundingClientRect();
          assert.true(
            secondLine.top > firstLine.top,
            "the badge has two visible lines"
          );
          assert.true(
            badge.height <= header.height,
            "both lines fit the normal header height"
          );
          assert.true(
            badge.right <= panel.left,
            "the badge does not overlap search or profile controls"
          );
          assertBesideControls("the topic badge stays beside the controls");
          assert.strictEqual(service.consumers, 2);
          await click(".dcs-header-dismiss");
          assert.strictEqual(service.consumers, 1);
          await visit("/");
          assert.dom(".dcs-header-restore").exists();
          assertBesideControls(
            "the homepage restore button stays beside the controls"
          );
          assert.strictEqual(service.consumers, 0);
          assert.strictEqual(service.timer, null);
          await click(".dcs-header-restore");
          assert.dom(".dcs-header-trigger").exists();
          assertBesideControls("the homepage badge stays beside the controls");
          assert.strictEqual(service.consumers, 1);
        });
      }
    }
  );
}

async function assertCompactStaysIdle(assert, container) {
  assert.dom(".dcs-mobile-header-trigger").exists({ count: 1 });
  assert.dom(".dcs-header-status").doesNotExist();
  const service = container.lookup("service:dcs-server-status");
  assert.strictEqual(service.consumers, 0);
  assert.strictEqual(service.timer, null);
  container.lookup("service:site-settings").search_experience = "search_field";
  await settled();
  assert.dom(".dcs-mobile-header-trigger").exists({ count: 1 });
}

for (const loggedIn of [false, true]) {
  acceptance(
    `DCS status | Compact desktop ${loggedIn ? "member" : "guest"} placement`,
    function (needs) {
      if (loggedIn) {
        needs.user();
      }
      needs.settings({
        dcs_server_status_enabled: true,
        dcs_server_status_header_enabled: true,
        search_experience: "search_icon",
        enable_welcome_banner: false,
      });
      needs.hooks.beforeEach(function () {
        const original = window.matchMedia.bind(window);
        const compactQuery = new EventTarget();
        compactQuery.matches = false;
        sinon
          .stub(window, "matchMedia")
          .callsFake((query) =>
            query === HEADER_MEDIA_QUERY ? compactQuery : original(query)
          );
      });
      needs.hooks.afterEach(function () {
        sinon.restore();
      });
      if (loggedIn) {
        test("uses one idle icon immediately before search", async function (assert) {
          await visit("/");
          const icon = document.querySelector(".dcs-mobile-header");
          assert.strictEqual(
            icon.nextElementSibling,
            document.querySelector(".search-dropdown"),
            "members see the fighter immediately before search"
          );
          await assertCompactStaysIdle(assert, this.container);
        });
      } else {
        test("uses one idle icon before authentication buttons", async function (assert) {
          await visit("/");
          const icon = document.querySelector(".dcs-mobile-header");
          const auth = document.querySelector(".auth-buttons");
          assert.strictEqual(
            icon.compareDocumentPosition(auth),
            Node.DOCUMENT_POSITION_FOLLOWING,
            "guests see the fighter before authentication buttons"
          );
          const gap =
            auth.getBoundingClientRect().left -
            icon.getBoundingClientRect().right;
          assert.true(gap >= 0, "no overlap");
          assert.true(gap <= 16, "no excess gap");
          await assertCompactStaysIdle(assert, this.container);
        });
      }
    }
  );
}

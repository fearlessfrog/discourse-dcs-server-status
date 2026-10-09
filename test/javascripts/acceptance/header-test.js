import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import KeyValueStore from "discourse/lib/key-value-store";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import {
  HEADER_HIDDEN_KEY,
  HEADER_STORE_NAMESPACE,
} from "discourse/plugins/discourse-dcs-server-status/discourse/services/dcs-header-preference";

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
        test("mobile has no header controls or header subscription", async function (assert) {
          await visit("/t/-/130");
          assert.dom(".cooked .dcs-server-status-card").exists();
          assert.dom(".d-header .dcs-header-status").doesNotExist();
          assert.strictEqual(
            this.container.lookup("service:dcs-server-status").consumers,
            1
          );
        });
      } else {
        test("header visibility, post cards and subscriptions survive topic navigation", async function (assert) {
          await visit("/t/-/130");
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
          assert.strictEqual(service.consumers, 2);
          await click(".dcs-header-dismiss");
          assert.strictEqual(service.consumers, 1);
          await visit("/");
          assert.dom(".dcs-header-restore").exists();
          assert.strictEqual(service.consumers, 0);
          assert.strictEqual(service.timer, null);
          await click(".dcs-header-restore");
          assert.dom(".dcs-header-trigger").exists();
          assert.strictEqual(service.consumers, 1);
        });
      }
    }
  );
}

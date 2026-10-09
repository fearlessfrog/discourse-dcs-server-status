import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const status = {
  status: "online",
  stale: false,
  server_name: "Example DCS Server",
  last_success_at: "2026-10-08T12:00:00Z",
  server: {
    name: "Example DCS Server",
    players: 0,
    players_max: 16,
    mission: "Example mission",
    mission_time_seconds: 172801,
    ip_address: "192.0.2.10",
    port: 10308,
  },
};

function configure(needs) {
  needs.settings({ dcs_server_status_enabled: true });
  needs.pretender((server, helper) => {
    const topic = cloneJSON(topicFixtures["/t/130.json"]);
    topic.post_stream.posts[0].cooked =
      '<div class="dcs-server-status-placeholder">DCS server status: view this post on the forum for live status.</div>';
    server.get("/t/130.json", () => helper.response(topic));
    server.get("/dcs-status.json", () => helper.response(status));
  });
}

for (const mobile of [false, true]) {
  acceptance(
    `DCS status | ${mobile ? "Mobile" : "Desktop"} post`,
    function (needs) {
      configure(needs);
      if (mobile) {
        needs.mobileView();
      }

      test("guests see a live inline card and navigation releases it", async function (assert) {
        await visit("/t/-/130");
        assert.dom(".cooked .dcs-server-status-card").exists();
        assert.dom(".cooked .dcs-server-status-card").includesText("0 / 16");
        assert
          .dom(".cooked .dcs-server-status-card")
          .includesText("2d 00:00:01");
        assert
          .dom(".cooked .dcs-server-status-placeholder")
          .doesNotIncludeText("view this post");

        await visit("/");
        const service = this.container.lookup("service:dcs-server-status");
        assert.strictEqual(service.consumers, 0);
        assert.strictEqual(service.timer, null);
      });
    }
  );
}

acceptance("DCS status | Composer preview", function (needs) {
  configure(needs);
  needs.user();

  test("the standalone shortcode becomes a live preview", async function (assert) {
    await visit("/t/-/130");
    await click(".topic-post[data-post-number='1'] button.reply");
    await fillIn(".d-editor-input", "[dcs-status]");
    assert.dom(".d-editor-preview .dcs-server-status-card").exists();
    assert
      .dom(".d-editor-preview .dcs-server-status-card")
      .includesText("Example mission");

    await fillIn(".d-editor-input", "```\n[dcs-status]\n```");
    assert.dom(".d-editor-preview .dcs-server-status-card").doesNotExist();
    assert.dom(".d-editor-preview code").hasText("[dcs-status]");
  });
});

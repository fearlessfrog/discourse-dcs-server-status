import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import DcsServerStatusConnection from "discourse/plugins/discourse-dcs-server-status/discourse/components/dcs-server-status-connection";

module("DCS status | Admin connection", function (hooks) {
  setupRenderingTest(hooks);

  test("queues a refresh and reloads safe diagnostics", async function (assert) {
    this.diagnostics = {
      configured: true,
      status: "unknown",
      error: "authentication_failed",
    };
    pretender.post(
      "/admin/plugins/discourse-dcs-server-status/refresh.json",
      () => response(202, { queued: true })
    );
    pretender.get(
      "/admin/plugins/discourse-dcs-server-status/connection.json",
      () => response({ configured: true, status: "online", error: null })
    );

    await render(
      <template>
        <DcsServerStatusConnection @diagnostics={{this.diagnostics}} />
      </template>
    );
    assert
      .dom(".dcs-server-status-connection")
      .includesText("ED authentication failed");
    await click(".dcs-server-status-connection button:first-of-type");
    assert.dom('[role="status"]').includesText("Refresh queued");
    await click(".dcs-server-status-connection button:last-of-type");
    assert.dom(".dcs-server-status-connection").includesText("Online");
  });
});

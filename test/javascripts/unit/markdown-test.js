import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { cook } from "discourse/lib/text";

module("DCS status | Markdown", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.owner.lookup("service:site-settings").dcs_server_status_enabled = true;
  });

  test("standalone shortcode renders the safe placeholder", async function (assert) {
    assert.true(
      (await cook("Before\n\n[dcs-status]\n\nAfter"))
        .toString()
        .includes('class="dcs-server-status-placeholder"')
    );
    this.owner.lookup("service:site-settings").dcs_server_status_enabled =
      false;
    assert.false(
      (await cook("[dcs-status]"))
        .toString()
        .includes('class="dcs-server-status-placeholder"')
    );
  });

  test("inline, escaped, and code examples remain literal", async function (assert) {
    for (const raw of [
      "Use [dcs-status] here",
      "\\[dcs-status]",
      "`[dcs-status]`",
      "```\n[dcs-status]\n```",
      "    [dcs-status]",
    ]) {
      assert.false(
        (await cook(raw))
          .toString()
          .includes('class="dcs-server-status-placeholder"'),
        raw
      );
    }
  });
});

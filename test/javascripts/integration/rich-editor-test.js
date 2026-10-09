import { module, test } from "qunit";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testMarkdown } from "discourse/tests/helpers/rich-editor-helper";
import richEditorExtension from "discourse/plugins/discourse-dcs-server-status/lib/rich-editor-extension";

module("DCS status | Rich editor", function (hooks) {
  setupRenderingTest(hooks);
  hooks.beforeEach(async function () {
    this.siteSettings.dcs_server_status_enabled = true;
    await resetRichEditorExtensions();
    registerRichEditorExtension(richEditorExtension);
  });
  hooks.afterEach(() => resetRichEditorExtensions());

  test("preserves the shortcode through a rich-editor round trip", async function (assert) {
    await testMarkdown(
      assert,
      "[dcs-status]",
      (domAssert) => {
        domAssert
          .dom(".ProseMirror .dcs-server-status-placeholder")
          .hasText("DCS server status (live when viewed)");
        domAssert
          .dom(".ProseMirror .dcs-server-status-placeholder")
          .hasAttribute("contenteditable", "false");
      },
      "[dcs-status]"
    );
  });
});

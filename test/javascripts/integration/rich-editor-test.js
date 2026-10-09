import { settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  setupRichEditor,
  testMarkdown,
} from "discourse/tests/helpers/rich-editor-helper";
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

  test("typing the shortcode creates a card node and preserves unescaped Markdown", async function (assert) {
    const [editor] = await setupRichEditor(assert, "");
    for (const character of "[dcs-status]") {
      editor.view.dispatch(editor.view.state.tr.insertText(character));
    }
    await settled();

    assert.dom(".ProseMirror .dcs-server-status-placeholder").exists();
    assert.strictEqual(editor.value, "[dcs-status]");

    editor.view.dispatch(editor.view.state.tr.insertText("After"));
    await settled();
    assert.dom(".ProseMirror .dcs-server-status-placeholder").exists();
    assert.strictEqual(editor.value, "[dcs-status]\n\nAfter");
  });

  test("preserves paragraph boundaries around multiple cards", async function (assert) {
    const markdown =
      "Before\n\n[dcs-status]\n\nBetween\n\n[dcs-status]\n\nAfter";
    await testMarkdown(
      assert,
      markdown,
      (domAssert) => {
        domAssert
          .dom(".ProseMirror .dcs-server-status-placeholder")
          .exists({ count: 2 });
        domAssert.dom(".ProseMirror").includesText("Between");
      },
      markdown
    );
  });

  test("pasting plain text creates a card node and preserves unescaped Markdown", async function (assert) {
    const [editor] = await setupRichEditor(assert, "");
    editor.view.pasteText("[dcs-status]");
    await settled();

    assert.dom(".ProseMirror .dcs-server-status-placeholder").exists();
    assert.strictEqual(editor.value, "[dcs-status]");
  });

  test("typing inline text keeps the shortcode literal", async function (assert) {
    const [editor] = await setupRichEditor(assert, "");
    for (const character of "Use [dcs-status] here") {
      editor.view.dispatch(editor.view.state.tr.insertText(character));
    }
    await settled();
    assert.dom(".ProseMirror .dcs-server-status-placeholder").doesNotExist();
  });

  test("editing an inline code example keeps the shortcode literal", async function (assert) {
    const [editor] = await setupRichEditor(assert, "`example`");
    editor.view.dispatch(editor.view.state.tr.insertText("[dcs-status]", 1, 8));
    await settled();

    assert.dom(".ProseMirror .dcs-server-status-placeholder").doesNotExist();
    assert.strictEqual(editor.value, "`[dcs-status]`");
  });

  test("typing in a code block keeps the shortcode literal", async function (assert) {
    const [editor] = await setupRichEditor(assert, "```\n\n```");
    editor.view.dispatch(editor.view.state.tr.insertText("[dcs-status]", 1));
    await settled();

    assert.dom(".ProseMirror pre").includesText("[dcs-status]");
    assert.dom(".ProseMirror .dcs-server-status-placeholder").doesNotExist();
    assert.strictEqual(editor.value, "```\n[dcs-status]\n```");
  });

  test("an existing escaped literal stays literal when another paragraph changes", async function (assert) {
    const [editor] = await setupRichEditor(assert, "\\[dcs-status\\]\n\nOther");
    editor.view.dispatch(
      editor.view.state.tr.insertText(
        "!",
        editor.view.state.doc.content.size - 1
      )
    );
    await settled();

    assert.dom(".ProseMirror .dcs-server-status-placeholder").doesNotExist();
    assert.strictEqual(editor.value, "\\[dcs-status\\]\n\nOther!");
  });
});
